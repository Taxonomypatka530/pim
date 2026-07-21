import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/protocol/framing.dart';
import '../core/protocol/wire_message.dart';
import '../models/peer_device.dart';

/// A control message received from an identified peer.
class InboundMessage {
  InboundMessage(this.peerId, this.message);
  final String peerId;
  final WireMessage message;
}

/// A binary file chunk received from an identified peer.
class InboundChunk {
  InboundChunk(this.peerId, this.transferId, this.index, this.data);
  final String peerId;
  final String transferId;
  final int index;
  final Uint8List data;
}

/// One live TCP connection to a peer, with its own frame reader.
class _PeerConnection {
  _PeerConnection(this.socket) : reader = FrameReader();
  final Socket socket;
  final FrameReader reader;
  String? remoteId;

  void send(WireMessage message) {
    socket.add(FrameCodec.encode(FrameKind.control, message.encode()));
  }

  void sendChunk(Uint8List body) {
    socket.add(FrameCodec.encode(FrameKind.chunk, body));
  }
}

/// Manages the TCP listener plus outgoing connections to peers.
///
/// Connections are kept alive and reused (one per peer id). On connect, both
/// sides exchange a [MsgType.hello] so an accepted socket — whose source port
/// is ephemeral — can be mapped back to a logical device id.
class TransportService {
  TransportService({
    required this.deviceId,
    required this.nameProvider,
    required this.platform,
  });

  /// Preferred TCP port; if taken we fall back to an OS-assigned free port.
  static const int preferredPort = 47821;

  final String deviceId;
  final String Function() nameProvider;
  final String platform;

  ServerSocket? _server;
  final Map<String, _PeerConnection> _byPeer = {};

  final StreamController<InboundMessage> _messages =
      StreamController<InboundMessage>.broadcast();
  final StreamController<InboundChunk> _chunks =
      StreamController<InboundChunk>.broadcast();
  final StreamController<String> _peerConnected =
      StreamController<String>.broadcast();

  Stream<InboundMessage> get onMessage => _messages.stream;
  Stream<InboundChunk> get onChunk => _chunks.stream;
  Stream<String> get onPeerConnected => _peerConnected.stream;

  int get port => _server?.port ?? 0;

  Future<void> start() async {
    ServerSocket server;
    try {
      server = await ServerSocket.bind(InternetAddress.anyIPv4, preferredPort);
    } catch (_) {
      server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    }
    server.listen(_handleAccepted, onError: (_) {});
    _server = server;
  }

  void _handleAccepted(Socket socket) {
    final conn = _PeerConnection(socket);
    _attach(conn);
    _sendHello(conn);
  }

  void _attach(_PeerConnection conn) {
    conn.socket.listen(
      (data) => conn.reader.add(Uint8List.fromList(data)),
      onError: (_) => _drop(conn),
      onDone: () => _drop(conn),
      cancelOnError: true,
    );
    conn.reader.frames.listen(
      (frame) => _onFrame(conn, frame),
      onError: (_) => _drop(conn),
    );
  }

  void _sendHello(_PeerConnection conn) {
    conn.send(WireMessage(MsgType.hello, {
      'id': deviceId,
      'name': nameProvider(),
      'platform': platform,
    }));
  }

  void _onFrame(_PeerConnection conn, Uint8List frame) {
    if (frame.isEmpty) return;
    final kind = frame[0];
    final body = Uint8List.sublistView(frame, 1);

    if (kind == FrameKind.chunk) {
      final id = conn.remoteId;
      if (id == null) return;
      final chunk = _decodeChunk(id, body);
      if (chunk != null) _chunks.add(chunk);
      return;
    }

    final WireMessage msg;
    try {
      msg = WireMessage.decode(body);
    } catch (_) {
      return;
    }

    if (msg.type == MsgType.hello) {
      final id = msg.str('id');
      if (id == null) return;
      conn.remoteId = id;
      // Newer connection replaces any stale one for the same peer.
      final previous = _byPeer[id];
      if (previous != null && !identical(previous, conn)) {
        _closeSilently(previous);
      }
      _byPeer[id] = conn;
      _peerConnected.add(id);
      return;
    }

    final id = conn.remoteId;
    if (id != null) {
      _messages.add(InboundMessage(id, msg));
    }
  }

  Future<_PeerConnection?> _ensureConnection(PeerDevice peer) async {
    final existing = _byPeer[peer.id];
    if (existing != null) return existing;

    try {
      final socket = await Socket.connect(
        peer.host,
        peer.port,
        timeout: const Duration(seconds: 5),
      );
      final conn = _PeerConnection(socket)..remoteId = peer.id;
      _byPeer[peer.id] = conn;
      _attach(conn);
      _sendHello(conn);
      return conn;
    } catch (_) {
      return null;
    }
  }

  /// Sends [message] to [peer], opening a connection if needed.
  /// Returns false if the peer is unreachable.
  Future<bool> sendTo(PeerDevice peer, WireMessage message) async {
    final conn = await _ensureConnection(peer);
    if (conn == null) return false;
    try {
      conn.send(message);
      return true;
    } catch (_) {
      _drop(conn);
      return false;
    }
  }

  /// Sends one binary chunk of [transferId] to [peer].
  Future<bool> sendChunkTo(
    PeerDevice peer,
    String transferId,
    int index,
    Uint8List data,
  ) async {
    final conn = await _ensureConnection(peer);
    if (conn == null) return false;
    try {
      conn.sendChunk(_encodeChunk(transferId, index, data));
      return true;
    } catch (_) {
      _drop(conn);
      return false;
    }
  }

  // Chunk body layout: [2-byte idLen][id utf8][4-byte index][data].
  static Uint8List _encodeChunk(String transferId, int index, Uint8List data) {
    final id = utf8.encode(transferId);
    final out = Uint8List(2 + id.length + 4 + data.length);
    out[0] = (id.length >> 8) & 0xFF;
    out[1] = id.length & 0xFF;
    out.setRange(2, 2 + id.length, id);
    final p = 2 + id.length;
    out[p] = (index >> 24) & 0xFF;
    out[p + 1] = (index >> 16) & 0xFF;
    out[p + 2] = (index >> 8) & 0xFF;
    out[p + 3] = index & 0xFF;
    out.setRange(p + 4, p + 4 + data.length, data);
    return out;
  }

  InboundChunk? _decodeChunk(String peerId, Uint8List body) {
    if (body.length < 6) return null;
    final idLen = (body[0] << 8) | body[1];
    if (body.length < 2 + idLen + 4) return null;
    final id = utf8.decode(body.sublist(2, 2 + idLen));
    final p = 2 + idLen;
    final index = (body[p] << 24) | (body[p + 1] << 16) | (body[p + 2] << 8) | body[p + 3];
    final data = Uint8List.sublistView(body, p + 4);
    return InboundChunk(peerId, id, index, Uint8List.fromList(data));
  }

  void _drop(_PeerConnection conn) {
    final id = conn.remoteId;
    if (id != null && identical(_byPeer[id], conn)) {
      _byPeer.remove(id);
    }
    _closeSilently(conn);
  }

  void _closeSilently(_PeerConnection conn) {
    conn.reader.close();
    try {
      conn.socket.destroy();
    } catch (_) {}
  }

  Future<void> stop() async {
    for (final conn in _byPeer.values.toList()) {
      _closeSilently(conn);
    }
    _byPeer.clear();
    await _server?.close();
    _server = null;
    await _messages.close();
    await _chunks.close();
    await _peerConnected.close();
  }
}
