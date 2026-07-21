import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../models/device_specs.dart';
import '../models/peer_device.dart';
import '../services/identity_service.dart';
import '../services/network_manager.dart';

/// Single source of truth for the UI. Holds the peer list, per-peer chat
/// history and app settings, and forwards actions to [NetworkManager].
class AppController extends ChangeNotifier {
  AppController(this._identity, this._network, this._specs);

  static const String _kLocale = 'pim.locale';
  static const String _kTheme = 'pim.theme_mode';

  final IdentityService _identity;
  final NetworkManager _network;
  final DeviceSpecs _specs;

  DeviceSpecs get specs => _specs;

  List<PeerDevice> _peers = const [];
  final Map<String, List<ChatMessage>> _chats = {};
  Locale? _locale; // null => follow system.
  ThemeMode _themeMode = ThemeMode.system;
  String? _localAddress; // this device's LAN IPv4, for display.

  StreamSubscription<List<PeerDevice>>? _peersSub;
  StreamSubscription<ChatMessage>? _messagesSub;

  List<PeerDevice> get peers => _peers;
  Locale? get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  String? get localAddress => _localAddress;
  Identity get me => _identity.identity;

  List<ChatMessage> chatWith(String peerId) => _chats[peerId] ?? const [];

  PeerDevice? peerById(String id) {
    for (final p in _peers) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Number of unread-ish? For now just total messages with a peer.
  int messageCountWith(String peerId) => _chats[peerId]?.length ?? 0;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocale);
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
    }
    _themeMode = _parseThemeMode(prefs.getString(_kTheme));
    _localAddress = await _detectLocalAddress();

    _peersSub = _network.peers.listen((list) {
      _peers = list;
      notifyListeners();
    });
    _messagesSub = _network.messages.listen((msg) {
      _chats.putIfAbsent(msg.peerId, () => <ChatMessage>[]).add(msg);
      notifyListeners();
    });

    try {
      await _network.start();
    } catch (e, st) {
      // Networking failure should not crash the app; UI still loads.
      debugPrint('NetworkManager failed to start: $e\n$st');
    }
  }

  Future<bool> sendText(String peerId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Future.value(false);
    return _network.sendText(peerId, trimmed);
  }

  Future<void> setDeviceName(String name) async {
    await _identity.setName(name);
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_kLocale);
    } else {
      await prefs.setString(_kLocale, locale.languageCode);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, mode.name);
  }

  static ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<String?> _detectLocalAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final ni in interfaces) {
        for (final addr in ni.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {
      // NetworkInterface.list can be unavailable on some sandboxes.
    }
    return null;
  }

  @override
  void dispose() {
    _peersSub?.cancel();
    _messagesSub?.cancel();
    _network.stop();
    super.dispose();
  }
}
