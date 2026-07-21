import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// The local device's stable identity.
class Identity {
  Identity({
    required this.deviceId,
    required this.name,
    required this.platform,
  });

  final String deviceId;
  String name;
  final String platform;
}

/// Loads and persists this device's identity (id, display name, platform).
///
/// The id is generated once on first launch and reused forever, so a peer can
/// recognise this device across restarts and IP changes.
class IdentityService {
  static const String _kId = 'pim.device_id';
  static const String _kName = 'pim.device_name';

  late Identity identity;

  Future<Identity> load() async {
    final prefs = await SharedPreferences.getInstance();

    var id = prefs.getString(_kId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_kId, id);
    }

    final platform = _detectPlatform();

    var name = prefs.getString(_kName);
    if (name == null || name.isEmpty) {
      name = _defaultName(platform);
      await prefs.setString(_kName, name);
    }

    identity = Identity(deviceId: id, name: name, platform: platform);
    return identity;
  }

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, trimmed);
    identity.name = trimmed;
  }

  static String _detectPlatform() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isAndroid) return 'android';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isIOS) return 'ios';
    return Platform.operatingSystem;
  }

  static String _defaultName(String platform) {
    try {
      final host = Platform.localHostname;
      if (host.trim().isNotEmpty) return host.trim();
    } catch (_) {
      // localHostname can throw on some sandboxed platforms; fall through.
    }
    switch (platform) {
      case 'windows':
        return 'Windows PC';
      case 'android':
        return 'Android device';
      default:
        return 'PIM device';
    }
  }
}
