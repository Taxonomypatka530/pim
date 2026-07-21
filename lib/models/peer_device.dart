import 'device_specs.dart';

/// A device discovered on the local network.
class PeerDevice {
  const PeerDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.host,
    required this.port,
    required this.lastSeen,
    this.specs = DeviceSpecs.unknown,
  });

  /// Stable, per-install unique id of the remote device.
  final String id;

  /// Human-friendly name the remote device advertises.
  final String name;

  /// 'windows' | 'android' | other OS name.
  final String platform;

  /// IPv4 address of the remote device on the LAN.
  final String host;

  /// TCP port the remote device is listening on for connections.
  final int port;

  /// When we last received a discovery announcement from this device.
  final DateTime lastSeen;

  /// Real hardware/OS characteristics advertised by the device.
  final DeviceSpecs specs;

  /// Considered online if seen recently. Discovery announces every ~2s.
  bool get isOnline =>
      DateTime.now().difference(lastSeen) < const Duration(seconds: 8);

  PeerDevice copyWith({
    String? name,
    String? platform,
    String? host,
    int? port,
    DateTime? lastSeen,
    DeviceSpecs? specs,
  }) {
    return PeerDevice(
      id: id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      host: host ?? this.host,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
      specs: specs ?? this.specs,
    );
  }

  @override
  bool operator ==(Object other) => other is PeerDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
