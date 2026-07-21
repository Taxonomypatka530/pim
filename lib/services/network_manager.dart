import 'dart:async';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../core/protocol/wire_message.dart';
import '../models/chat_message.dart';
import '../models/device_specs.dart';
import '../models/peer_device.dart';
import 'discovery_service.dart';
import 'identity_service.dart';
import 'transport_service.dart';

/// Top-level networking facade the UI talks to.
///
/// Wires discovery (who is out there) to transport (how we reach them), keeps a
/// live registry of peers, and exposes simple streams: [peers] and [messages].
class NetworkManager {
  NetworkManager(this._identity, this._specs);

  final IdentityService _identity;
  final DeviceSpecs _specs;
  static const Uuid _uuid = Uuid();

  late final TransportService _transport;
  late final DiscoveryService _discovery;

  final Map<String, PeerDevice> _peers = {};
  Timer? _expiryTimer;

  final StreamController<List<PeerDevice>> _peersController =
      StreamController<List<PeerDevice>>.broadcast();
  final StreamController<ChatMessage> _messagesController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<InboundMessage> _controlController =
      StreamController<InboundMessage>.broadcast();
  final StreamController<InboundChunk> _chunkController =
      StreamController<InboundChunk>.broadcast();

  Stream<List<PeerDevice>> get peers => _peersController.stream;
  Stream<ChatMessage> get messages => _messagesController.stream;

  /// Every inbound control message (workspace/file signalling live here).
  Stream<InboundMessage> get control => _controlController.stream;

  /// Every inbound binary file chunk.
  Stream<InboundChunk> get chunks => _chunkController.stream;

  PeerDevice? peer(String id) => _peers[id];

  List<PeerDevice> get currentPeers {
    final list = _peers.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Identity get me => _identity.identity;

  Future<void> start() async {
    _transport = TransportService(
      deviceId: me.deviceId,
      nameProvider: () => me.name,
      platform: me.platform,
    );
    await _transport.start();
    _transport.onMessage.listen(_onInbound);
    _transport.onChunk.listen(_chunkController.add);

    _discovery = DiscoveryService(
      deviceId: me.deviceId,
      nameProvider: () => me.name,
      platform: me.platform,
      tcpPortProvider: () => _transport.port,
      specs: _specs,
    );
    await _discovery.start();
    _discovery.onPeer.listen(_onDiscovered);

    _expiryTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _expireStale());
  }

  void _onDiscovered(DiscoveredPeer p) {
    if (p.tcpPort == 0) return; // peer's transport not ready yet.
    _peers[p.id] = PeerDevice(
      id: p.id,
      name: p.name,
      platform: p.platform,
      host: p.address.address,
      port: p.tcpPort,
      lastSeen: DateTime.now(),
      specs: p.specs,
    );
    _emitPeers();
  }

  void _expireStale() {
    final now = DateTime.now();
    _peers.removeWhere(
      (_, d) => now.difference(d.lastSeen) > const Duration(seconds: 12),
    );
    // Re-emit unconditionally so online/offline chips refresh over time even
    // when the peer set itself is unchanged.
    _emitPeers();
  }

  void _onInbound(InboundMessage inbound) {
    // Fan out to workspace/file managers.
    _controlController.add(inbound);

    if (inbound.message.type == MsgType.text) {
      final body = inbound.message.str('body') ?? '';
      final id = inbound.message.str('id') ?? _uuid.v4();
      _messagesController.add(ChatMessage(
        id: id,
        peerId: inbound.peerId,
        direction: ChatDirection.incoming,
        text: body,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Sends a text message to [peerId]. Returns false if delivery failed.
  Future<bool> sendText(String peerId, String body) async {
    final peer = _peers[peerId];
    if (peer == null) return false;

    final id = _uuid.v4();
    final ok = await _transport.sendTo(
      peer,
      WireMessage(MsgType.text, {
        'id': id,
        'from': me.deviceId,
        'body': body,
      }),
    );

    if (ok) {
      _messagesController.add(ChatMessage(
        id: id,
        peerId: peerId,
        direction: ChatDirection.outgoing,
        text: body,
        timestamp: DateTime.now(),
      ));
    }
    return ok;
  }

  /// Sends a control message to [peerId]. Returns false if the peer is unknown
  /// or unreachable.
  Future<bool> sendControl(String peerId, WireMessage message) {
    final target = _peers[peerId];
    if (target == null) return Future.value(false);
    return _transport.sendTo(target, message);
  }

  /// Sends one binary chunk of [transferId] to [peerId].
  Future<bool> sendChunk(
    String peerId,
    String transferId,
    int index,
    Uint8List data,
  ) {
    final target = _peers[peerId];
    if (target == null) return Future.value(false);
    return _transport.sendChunkTo(target, transferId, index, data);
  }

  void _emitPeers() => _peersController.add(currentPeers);

  Future<void> stop() async {
    _expiryTimer?.cancel();
    await _discovery.stop();
    await _transport.stop();
    await _peersController.close();
    await _messagesController.close();
    await _controlController.close();
    await _chunkController.close();
  }
}
