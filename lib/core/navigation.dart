import 'package:flutter/widgets.dart';

/// Root navigator key, assigned to [MaterialApp.navigatorKey].
///
/// Lets the custom window title bar — which lives *above* the app's Navigator in
/// the widget tree — push routes (e.g. Settings) onto the app.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
