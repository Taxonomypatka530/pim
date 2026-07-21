import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/navigation.dart';
import '../../l10n/app_localizations.dart';
import '../brand/logo.dart';
import '../settings_screen.dart';
import 'top_bar.dart';

/// The custom, frameless title bar drawn at the very top of the desktop window.
///
/// Left: the PIM wordmark. The whole bar is a drag handle (double-click toggles
/// maximize). Right: our own minimize / maximize-restore / close buttons.
class WindowBar extends StatefulWidget {
  const WindowBar({super.key});

  static const double height = 46;

  @override
  State<WindowBar> createState() => _WindowBarState();
}

class _WindowBarState extends State<WindowBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _maximized = v);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  Widget _dragHandle(Widget child) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: _toggleMaximize,
      onPanStart: (_) => windowManager.startDragging(),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    // Material ancestor gives our Text widgets a proper default style — without
    // it, text drawn in the (non-Scaffold) title bar shows the framework's
    // debug yellow underline.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: WindowBar.height,
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<String?>(
                valueListenable: workspaceTopTitle,
                builder: (context, title, _) {
                  if (title == null) {
                    return _dragHandle(
                      const Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PimLogo(height: 20),
                        ),
                      ),
                    );
                  }
                  return Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        onPressed: () =>
                            rootNavigatorKey.currentState?.maybePop(),
                      ),
                      Expanded(
                        child: _dragHandle(
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            _ToolbarButton(
              icon: Icons.settings_rounded,
              label: l.settings,
              onTap: () => rootNavigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(width: 4),
            _WindowButton(
              tooltip: l.minimize,
              icon: _WindowIcons.minimize,
              onPressed: () => windowManager.minimize(),
            ),
            _WindowButton(
              tooltip: _maximized ? l.restore : l.maximize,
              icon: _maximized ? _WindowIcons.restore : _WindowIcons.maximize,
              onPressed: _toggleMaximize,
            ),
            _WindowButton(
              tooltip: l.close,
              icon: _WindowIcons.close,
              isClose: true,
              onPressed: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled action in the title bar (icon + text) with a hover highlight.
class _ToolbarButton extends StatefulWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _hovering
                ? scheme.onSurface.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  final String tooltip;
  final _WindowIcons icon;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hoverBg = widget.isClose
        ? const Color(0xFFE81123)
        : scheme.onSurface.withValues(alpha: 0.10);
    final fg = (_hovering && widget.isClose) ? Colors.white : scheme.onSurface;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 46,
            height: WindowBar.height,
            color: _hovering ? hoverBg : Colors.transparent,
            child: Center(
              child: CustomPaint(
                size: const Size(10, 10),
                painter: _WindowGlyphPainter(widget.icon, fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _WindowIcons { minimize, maximize, restore, close }

// Simple crisp glyphs so the controls look native at any DPI.
class _WindowGlyphPainter extends CustomPainter {
  _WindowGlyphPainter(this.kind, this.color);
  final _WindowIcons kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final w = size.width, h = size.height;

    switch (kind) {
      case _WindowIcons.minimize:
        canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), paint);
      case _WindowIcons.maximize:
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
      case _WindowIcons.restore:
        canvas.drawRect(Rect.fromLTWH(0, 2, w - 2, h - 2), paint);
        canvas.drawLine(const Offset(2, 2), const Offset(2, 0), paint);
        canvas.drawLine(const Offset(2, 0), Offset(w, 0), paint);
        canvas.drawLine(Offset(w, 0), Offset(w, h - 2), paint);
        canvas.drawLine(Offset(w, h - 2), Offset(w - 2, h - 2), paint);
      case _WindowIcons.close:
        canvas.drawLine(const Offset(0, 0), Offset(w, h), paint);
        canvas.drawLine(Offset(0, h), Offset(w, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_WindowGlyphPainter old) =>
      old.kind != kind || old.color != color;
}
