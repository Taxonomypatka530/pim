import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/device_specs.dart';

/// A peer heard from a single UDP discovery announcement.
class DiscoveredPeer {
  DiscoveredPeer({
    required this.id,
    required this.name,
    required this.platform,
    required this.address,
    required this.tcpPort,
    required this.specs,
  });

  final String id;
  final String name;
  final String platform;
  final InternetAddress address;
  final int tcpPort;
  final DeviceSpecs specs;
}

/// Peer discovery over UDP broadcast — pure Dart, identical on Windows/Android.
///
/// Every [announceInterval] we broadcast a small JSON packet describing this
/// device (id, name, platform, TCP port) to the whole subnet. We also listen on
/// the same port and surface everyone else's announcements on [onPeer].
///
/// No mDNS plugin, no platform channels: one UDP socket, fully under our
/// control, so behaviour is the same on every OS.
class DiscoveryService {
  DiscoveryService({
    required this.deviceId,
    required this.nameProvider,
    required this.platform,
    required this.tcpPortProvider,
    required this.specs,
  });

  /// Fixed UDP port all PIM instances agree on for discovery.
  static const int discoveryPort = 47820;

  /// Magic tag so we ignore any unrelated UDP traffic on the port.
  static const String _magic = 'PIM/1';

  static const Duration announceInterval = Duration(seconds: 2);

  final String deviceId;
  final String Function() nameProvider;
  final String platform;
  final int Function() tcpPortProvider;
  final DeviceSpecs specs;

  RawDatagramSocket? _socket;
  Timer? _announceTimer;
  final StreamController<DiscoveredPeer> _controller =
      StreamController<DiscoveredPeer>.broadcast();

  Stream<DiscoveredPeer> get onPeer => _controller.stream;

  Future<void> start() async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
    );
    socket.broadcastEnabled = true;
    socket.listen(_onEvent);
    _socket = socket;

    _announce();
    _announceTimer = Timer.periodic(announceInterval, (_) => _announce());
  }

  void _announce() {
    final socket = _socket;
    if (socket == null) return;

    final payload = utf8.encode(jsonEncode(<String, dynamic>{
      'app': _magic,
      'id': deviceId,
      'name': nameProvider(),
      'platform': platform,
      'port': tcpPortProvider(),
      ...specs.toAnnounce(),
    }));

    try {
      socket.send(payload, InternetAddress('255.255.255.255'), discoveryPort);
    } catch (_) {
      // Broadcast can transiently fail while the network interface is changing.
    }
  }

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;

    try {
      final decoded = jsonDecode(utf8.decode(datagram.data));
      if (decoded is! Map) return;
      if (decoded['app'] != _magic) return;

      final id = decoded['id'] as String?;
      if (id == null || id == deviceId) return; // ignore ourselves.

      _controller.add(DiscoveredPeer(
        id: id,
        name: (decoded['name'] as String?) ?? id,
        platform: (decoded['platform'] as String?) ?? 'unknown',
        address: datagram.address,
        tcpPort: (decoded['port'] as int?) ?? 0,
        specs: DeviceSpecs.fromAnnounce(decoded),
      ));
    } catch (_) {
      // Malformed packet — ignore.
    }
  }

  Future<void> stop() async {
    _announceTimer?.cancel();
    _socket?.close();
    _socket = null;
    await _controller.close();
  }
}
