import 'package:flutter/foundation.dart';

/// When set (by a screen that wants its title shown in the custom desktop window
/// bar instead of a separate app bar), the [WindowBar] renders a back button +
/// this title in place of the logo. Cleared when the screen is popped.
final ValueNotifier<String?> workspaceTopTitle = ValueNotifier<String?>(null);
