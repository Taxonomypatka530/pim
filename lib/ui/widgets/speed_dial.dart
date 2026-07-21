import 'dart:math' as math;

import 'package:flutter/material.dart';

class SpeedDialAction {
  const SpeedDialAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// A bottom-left FAB that expands into a single rounded menu panel.
class SpeedDial extends StatefulWidget {
  const SpeedDial({super.key, required this.actions});
  final List<SpeedDialAction> actions;

  @override
  State<SpeedDial> createState() => _SpeedDialState();
}

class _SpeedDialState extends State<SpeedDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _c.forward() : _c.reverse();
  }

  void _run(VoidCallback cb) {
    _toggle();
    cb();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final anim = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    final maxW = math.min(230.0, MediaQuery.of(context).size.width - 40);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One cohesive, compact rounded menu panel.
        SizeTransition(
          sizeFactor: anim,
          child: FadeTransition(
            opacity: anim,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                constraints: BoxConstraints(
                  minWidth: math.min(176.0, maxW),
                  maxWidth: maxW,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.actions.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      _item(widget.actions[i], scheme),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        FloatingActionButton(
          heroTag: 'speeddial-main',
          mouseCursor: SystemMouseCursors.click,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          onPressed: _toggle,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Transform.rotate(
              angle: _c.value * math.pi * 0.75,
              child: const Icon(Icons.add_rounded, size: 28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(SpeedDialAction action, ColorScheme scheme) {
    return InkWell(
      onTap: () => _run(action.onTap),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(action.icon, color: scheme.primary, size: 20),
            const SizedBox(width: 14),
            Text(
              action.label,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
