import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/protocol/wire_message.dart';
import '../models/file_record.dart';
import '../models/file_transfer.dart';
import '../models/workspace.dart';
import 'identity_service.dart';
import 'network_manager.dart';
import 'transport_service.dart';
import 'workspace_manager.dart';

class _SendJob {
  _SendJob(this.file);
  final File file;
}

class _RecvJob {
  _RecvJob({
    required this.transfer,
    required this.sink,
    required this.temp,
    required this.dir,
    required this.folderId,
    required this.hashInput,
    required this.hashOutput,
  });

  final FileTransfer transfer;
  final IOSink sink;
  final File temp;
  final Directory dir;
  final String? folderId;
  final ByteConversionSink hashInput;
  final AccumulatorSink<Digest> hashOutput;
}

/// Chunked, hash-verified file transfer between workspace members.
///
/// Flow: sender sends [MsgType.fileOffer]; receiver (in a shared space) auto
/// accepts with [MsgType.fileAccept] and opens a temp file; sender streams
/// binary chunks while hashing incrementally, then sends [MsgType.fileComplete]
/// with the SHA-256; receiver verifies the hash before moving the temp file to
/// its final location.
class FileTransferManager extends ChangeNotifier {
  FileTransferManager(this._identity, this._network, this._workspaces) {
    _controlSub = _network.control.listen(_onControl);
    _chunkSub = _network.chunks.listen(_onChunk);
  }

  static const Uuid _uuid = Uuid();
  static const int _chunkSize = 64 * 1024;

  final IdentityService _identity;
  final NetworkManager _network;
  final WorkspaceManager _workspaces;
  late final StreamSubscription<InboundMessage> _controlSub;
  late final StreamSubscription<InboundChunk> _chunkSub;

  final List<FileTransfer> _transfers = [];
  final Map<String, _SendJob> _sends = {};
  final Map<String, _RecvJob> _recvs = {};

  String get _myId => _identity.identity.deviceId;

  /// Newest first.
  List<FileTransfer> get transfers => _transfers.reversed.toList();

  List<FileTransfer> transfersFor(String workspaceId) =>
      _transfers.reversed.where((t) => t.workspaceId == workspaceId).toList();

  // --- Sending --------------------------------------------------------------

  /// Sends [file] to every other member of [ws], filed under [folderId].
  Future<void> sendFile(Workspace ws, File file, {String? folderId}) async {
    final name = file.uri.pathSegments.isEmpty
        ? 'file'
        : file.uri.pathSegments.last;
    final size = await file.length();

    // The sender sees the file appear in the folder immediately.
    _workspaces.addFile(FileRecord(
      id: _uuid.v4(),
      workspaceId: ws.id,
      folderId: folderId,
      name: name,
      size: size,
      path: file.path,
      sha256: null,
      incoming: false,
      peerName: '',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));

    for (final m in ws.others(_myId)) {
      await _offer(ws.id, m.id, m.name, file, name, size, folderId);
    }
  }

  Future<void> _offer(
    String workspaceId,
    String peerId,
    String peerName,
    File file,
    String fileName,
    int size,
    String? folderId,
  ) async {
    final id = _uuid.v4();
    final transfer = FileTransfer(
      id: id,
      workspaceId: workspaceId,
      peerId: peerId,
      peerName: peerName,
      fileName: fileName,
      size: size,
      direction: TransferDirection.outgoing,
      status: TransferStatus.offered,
    );
    _transfers.add(transfer);
    _sends[id] = _SendJob(file);
    notifyListeners();

    final ok = await _network.sendControl(
      peerId,
      WireMessage(MsgType.fileOffer, {
        'transferId': id,
        'workspaceId': workspaceId,
        'fileName': fileName,
        'size': size,
        'from': _myId,
        'fromName': _identity.identity.name,
        'folderId': folderId,
      }),
    );
    if (!ok) {
      transfer.status = TransferStatus.failed;
      transfer.error = 'offer_failed';
      _sends.remove(id);
      notifyListeners();
    }
  }

  Future<void> _streamFile(FileTransfer transfer, _SendJob job) async {
    final hashOutput = AccumulatorSink<Digest>();
    final hashInput = sha256.startChunkedConversion(hashOutput);
    try {
      transfer.status = TransferStatus.transferring;
      _bump();

      var index = 0;
      await for (final block
          in job.file.openRead().transform(_rechunk(_chunkSize))) {
        hashInput.add(block);
        final ok = await _network.sendChunk(
            transfer.peerId, transfer.id, index, block);
        if (!ok) throw StateError('chunk_send_failed');
        index++;
        transfer.transferred += block.length;
        _bump();
      }

      hashInput.close();
      final digest = hashOutput.events.single.toString();
      await _network.sendControl(
        transfer.peerId,
        WireMessage(MsgType.fileComplete,
            {'transferId': transfer.id, 'sha256': digest}),
      );
      transfer.transferred = transfer.size;
      transfer.status = TransferStatus.completed;
      notifyListeners();
    } catch (e) {
      transfer.status = TransferStatus.failed;
      transfer.error = '$e';
      _network.sendControl(transfer.peerId,
          WireMessage(MsgType.fileCancel, {'transferId': transfer.id}));
      notifyListeners();
    } finally {
      _sends.remove(transfer.id);
    }
  }

  // --- Inbound --------------------------------------------------------------

  void _onControl(InboundMessage inbound) {
    switch (inbound.message.type) {
      case MsgType.fileOffer:
        _onOffer(inbound);
      case MsgType.fileAccept:
        _onAccept(inbound);
      case MsgType.fileReject:
        _onReject(inbound);
      case MsgType.fileComplete:
        _onComplete(inbound);
      case MsgType.fileCancel:
        _onCancel(inbound);
    }
  }

  Future<void> _onOffer(InboundMessage inbound) async {
    final id = inbound.message.str('transferId');
    if (id == null || _recvs.containsKey(id)) return;
    final size = inbound.message.integer('size') ?? 0;
    final fileName = inbound.message.str('fileName') ?? 'file';

    final transfer = FileTransfer(
      id: id,
      workspaceId: inbound.message.str('workspaceId') ?? '',
      peerId: inbound.peerId,
      peerName: inbound.message.str('fromName') ?? inbound.peerId,
      fileName: fileName,
      size: size,
      direction: TransferDirection.incoming,
      status: TransferStatus.transferring,
    );
    _transfers.add(transfer);
    notifyListeners();

    try {
      final dir = await _saveDir(transfer.workspaceId);
      final temp = File('${dir.path}/.$id.part');
      final sink = temp.openWrite();
      final hashOutput = AccumulatorSink<Digest>();
      final hashInput = sha256.startChunkedConversion(hashOutput);
      _recvs[id] = _RecvJob(
        transfer: transfer,
        sink: sink,
        temp: temp,
        dir: dir,
        folderId: inbound.message.str('folderId'),
        hashInput: hashInput,
        hashOutput: hashOutput,
      );
      await _network.sendControl(
          inbound.peerId, WireMessage(MsgType.fileAccept, {'transferId': id}));
    } catch (e) {
      transfer.status = TransferStatus.failed;
      transfer.error = '$e';
      notifyListeners();
    }
  }

  void _onAccept(InboundMessage inbound) {
    final id = inbound.message.str('transferId');
    if (id == null) return;
    final job = _sends[id];
    if (job == null) return;
    final transfer = _transferById(id);
    if (transfer == null) return;
    _streamFile(transfer, job);
  }

  void _onReject(InboundMessage inbound) {
    final id = inbound.message.str('transferId');
    final transfer = id == null ? null : _transferById(id);
    if (transfer == null) return;
    transfer.status = TransferStatus.rejected;
    _sends.remove(id);
    notifyListeners();
  }

  void _onChunk(InboundChunk chunk) {
    final job = _recvs[chunk.transferId];
    if (job == null) return;
    job.sink.add(chunk.data);
    job.hashInput.add(chunk.data);
    job.transfer.transferred += chunk.data.length;
    _bump();
  }

  Future<void> _onComplete(InboundMessage inbound) async {
    final id = inbound.message.str('transferId');
    if (id == null) return;
    final job = _recvs.remove(id);
    if (job == null) return;

    try {
      await job.sink.flush();
      await job.sink.close();
      job.hashInput.close();
      final actual = job.hashOutput.events.single.toString();
      final expected = inbound.message.str('sha256');

      if (expected != null && expected != actual) {
        job.transfer.status = TransferStatus.failed;
        job.transfer.error = 'integrity_mismatch';
        try {
          await job.temp.delete();
        } catch (_) {}
      } else {
        final finalPath = await _uniquePath(job.dir, job.transfer.fileName);
        await job.temp.rename(finalPath);
        job.transfer.transferred = job.transfer.size;
        job.transfer.savePath = finalPath;
        job.transfer.status = TransferStatus.completed;
        _workspaces.addFile(FileRecord(
          id: job.transfer.id,
          workspaceId: job.transfer.workspaceId,
          folderId: job.folderId,
          name: job.transfer.fileName,
          size: job.transfer.size,
          path: finalPath,
          sha256: actual,
          incoming: true,
          peerName: job.transfer.peerName,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } catch (e) {
      job.transfer.status = TransferStatus.failed;
      job.transfer.error = '$e';
    }
    notifyListeners();
  }

  Future<void> _onCancel(InboundMessage inbound) async {
    final id = inbound.message.str('transferId');
    if (id == null) return;
    final job = _recvs.remove(id);
    if (job == null) return;
    try {
      await job.sink.close();
      await job.temp.delete();
    } catch (_) {}
    job.transfer.status = TransferStatus.failed;
    job.transfer.error = 'cancelled';
    notifyListeners();
  }

  // --- Helpers --------------------------------------------------------------

  FileTransfer? _transferById(String id) {
    for (final t in _transfers) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Received files land in a per-workspace folder named after the workspace,
  /// under `Downloads/PIM/`.
  Future<Directory> _saveDir(String workspaceId) async {
    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {}
    dir ??= await getApplicationDocumentsDirectory();
    final ws = _workspaces.workspaceById(workspaceId);
    final sub = _sanitize(ws?.name ?? 'workspace');
    final target = Directory('${dir.path}/PIM/$sub');
    if (!await target.exists()) await target.create(recursive: true);
    return target;
  }

  static String _sanitize(String name) {
    final s = name.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return s.isEmpty ? 'workspace' : s;
  }

  Future<String> _uniquePath(Directory dir, String name) async {
    if (!await File('${dir.path}/$name').exists()) return '${dir.path}/$name';
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    var i = 1;
    while (await File('${dir.path}/$base ($i)$ext').exists()) {
      i++;
    }
    return '${dir.path}/$base ($i)$ext';
  }

  // Re-chunks an arbitrary byte stream into fixed-size Uint8List blocks.
  StreamTransformer<List<int>, Uint8List> _rechunk(int size) {
    final buffer = BytesBuilder(copy: false);
    return StreamTransformer<List<int>, Uint8List>.fromHandlers(
      handleData: (data, sink) {
        buffer.add(data);
        while (buffer.length >= size) {
          final bytes = buffer.takeBytes();
          var offset = 0;
          while (offset + size <= bytes.length) {
            sink.add(Uint8List.sublistView(bytes, offset, offset + size));
            offset += size;
          }
          if (offset < bytes.length) {
            buffer.add(Uint8List.sublistView(bytes, offset));
          }
        }
      },
      handleDone: (sink) {
        if (buffer.length > 0) sink.add(buffer.takeBytes());
        sink.close();
      },
    );
  }

  bool _notifyScheduled = false;
  void _bump() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    Future.delayed(const Duration(milliseconds: 100), () {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _controlSub.cancel();
    _chunkSub.cancel();
    for (final job in _recvs.values) {
      job.sink.close().catchError((_) {});
    }
    super.dispose();
  }
}
