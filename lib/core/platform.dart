import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// True on desktop platforms where we manage a custom (frameless) window and
/// draw our own title bar. Android/iOS use the OS chrome instead.
bool get isDesktopWindowing =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
