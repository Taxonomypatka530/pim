import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:system_info2/system_info2.dart';
import 'package:win32_registry/win32_registry.dart';

import '../models/device_specs.dart';

/// Collects this device's real hardware/OS characteristics.
///
/// OS name + model come from device_info_plus; CPU arch/cores and total RAM come
/// from system_info2 (consistent across Windows and Android). Everything is
/// wrapped in try/catch so a failure on any platform degrades gracefully.
class DeviceInfoService {
  static Future<DeviceSpecs> collect() async {
    String osName = '';
    String model = '';
    String cpuName = '';
    String cpuArch = '';
    int cpuCores = 0;
    int ramMb = 0;

    try {
      final info = DeviceInfoPlugin();
      if (Platform.isWindows) {
        final w = await info.windowsInfo;
        final isWin11 = w.buildNumber >= 22000;
        final base = isWin11 ? 'Windows 11' : 'Windows 10';
        osName = w.displayVersion.isNotEmpty ? '$base ${w.displayVersion}' : base;
        model = w.computerName;
        cpuCores = w.numberOfCores;
        ramMb = w.systemMemoryInMegabytes;
        cpuName = _windowsCpuName();
      } else if (Platform.isAndroid) {
        final a = await info.androidInfo;
        osName = 'Android ${a.version.release}';
        model = _cleanModel(a.manufacturer, a.model);
        if (a.supportedAbis.isNotEmpty) cpuArch = a.supportedAbis.first;
      }
    } catch (e) {
      debugPrint('device_info_plus failed: $e');
    }

    // system_info2 fills in what device_info_plus doesn't expose per platform.
    try {
      final cores = SysInfo.cores;
      if (cpuCores == 0) cpuCores = cores.length;
      if (cpuName.isEmpty && cores.isNotEmpty) {
        cpuName = _cleanCpuName(cores.first.name);
      }
      if (cpuArch.isEmpty) cpuArch = SysInfo.rawKernelArchitecture;
      if (ramMb == 0) {
        ramMb = (SysInfo.getTotalPhysicalMemory() / (1024 * 1024)).round();
      }
    } catch (e) {
      debugPrint('system_info2 failed: $e');
    }

    return DeviceSpecs(
      osName: osName,
      model: model,
      cpuName: cpuName,
      cpuArch: cpuArch,
      cpuCores: cpuCores,
      ramMb: ramMb,
    );
  }

  /// Reads the CPU brand string straight from the Windows registry — the same
  /// source the OS uses. Works on Windows 11 24H2+ where `wmic` (which
  /// system_info2 relies on) has been removed.
  static String _windowsCpuName() {
    RegistryKey? key;
    try {
      key = Registry.openPath(
        RegistryHive.localMachine,
        path: r'HARDWARE\DESCRIPTION\System\CentralProcessor\0',
      );
      final name = key.getStringValue('ProcessorNameString') ?? '';
      return _cleanCpuName(name);
    } catch (e) {
      debugPrint('registry cpu name failed: $e');
      return '';
    } finally {
      key?.close();
    }
  }

  /// Tidies a raw CPU brand string into something compact and readable,
  /// e.g. "AMD Ryzen 9 5900X 12-Core Processor" -> "AMD Ryzen 9 5900X".
  static String _cleanCpuName(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    s = s
        .replaceAll(RegExp(r'\(R\)|\(TM\)|\(tm\)|\(r\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+@.*$'), '') // drop "@ 3.70GHz"
        .replaceAll(RegExp(r'\s*\d+-Core Processor', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bProcessor\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bCPU\b'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    return s;
  }

  /// Avoids duplicated manufacturer in the model string (e.g. "Samsung SM-...").
  static String _cleanModel(String manufacturer, String model) {
    final m = manufacturer.trim();
    final md = model.trim();
    if (m.isEmpty) return md;
    if (md.toLowerCase().startsWith(m.toLowerCase())) return md;
    return '$m $md';
  }
}
