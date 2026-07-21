import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/navigation.dart';
import 'core/platform.dart';
import 'l10n/app_localizations.dart';
import 'state/app_controller.dart';
import 'ui/brand/theme.dart';
import 'ui/home_screen.dart';
import 'ui/window/window_bar.dart';

class PimApp extends StatelessWidget {
  const PimApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.select<AppController, Locale?>((c) => c.locale);
    final themeMode =
        context.select<AppController, ThemeMode>((c) => c.themeMode);

    return MaterialApp(
      title: 'PIM',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: pimTheme(Brightness.light),
      darkTheme: pimTheme(Brightness.dark),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (!isDesktopWindowing) return content;
        // Custom frameless chrome: our title bar on top, app below.
        // Wrapped in an Overlay so the title bar's tooltips have an Overlay
        // ancestor (the app's own Overlay lives inside `content`, below us).
        return Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => Column(
                children: [const WindowBar(), Expanded(child: content)],
              ),
            ),
          ],
        );
      },
      home: const HomeScreen(),
    );
  }
}
