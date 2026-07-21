/// Real hardware/OS characteristics of a device.
///
/// Gathered locally for this device and also advertised to peers (compactly)
/// inside the discovery packet so their cards can show the same details.
class DeviceSpecs {
  const DeviceSpecs({
    required this.osName,
    required this.model,
    required this.cpuName,
    required this.cpuArch,
    required this.cpuCores,
    required this.ramMb,
  });

  /// e.g. "Windows 11 24H2", "Android 14".
  final String osName;

  /// Computer name / phone model, e.g. "MATROS-PC", "Pixel 8".
  final String model;

  /// CPU model / brand string, e.g. "AMD Ryzen 9 5900X", "Intel Core i7-12700".
  final String cpuName;

  /// CPU architecture, e.g. "x86_64", "aarch64".
  final String cpuArch;

  /// Number of logical CPU cores.
  final int cpuCores;

  /// Total physical RAM in megabytes.
  final int ramMb;

  static const DeviceSpecs unknown = DeviceSpecs(
    osName: '',
    model: '',
    cpuName: '',
    cpuArch: '',
    cpuCores: 0,
    ramMb: 0,
  );

  bool get hasCpuName => cpuName.isNotEmpty;
  bool get hasCpu => cpuCores > 0;
  bool get hasRam => ramMb > 0;
  bool get hasOs => osName.isNotEmpty;
  bool get isKnown => hasCpu || hasRam || hasOs;

  /// A human label for RAM, rounded to whole GB (e.g. "32 GB").
  String get ramLabel {
    if (ramMb <= 0) return '';
    if (ramMb < 1024) return '$ramMb MB';
    final gb = ramMb / 1024;
    final rounded = gb >= 8 ? gb.round() : double.parse(gb.toStringAsFixed(1));
    final text = rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toString();
    return '$text GB';
  }

  /// Compact map for the discovery packet (short keys to keep UDP small).
  Map<String, dynamic> toAnnounce() => {
        'os': osName,
        'md': model,
        'cn': cpuName,
        'ca': cpuArch,
        'cc': cpuCores,
        'rm': ramMb,
      };

  factory DeviceSpecs.fromAnnounce(Map<dynamic, dynamic> m) => DeviceSpecs(
        osName: (m['os'] as String?) ?? '',
        model: (m['md'] as String?) ?? '',
        cpuName: (m['cn'] as String?) ?? '',
        cpuArch: (m['ca'] as String?) ?? '',
        cpuCores: (m['cc'] as int?) ?? 0,
        ramMb: (m['rm'] as int?) ?? 0,
      );
}
