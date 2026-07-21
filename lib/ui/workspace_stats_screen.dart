import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/media_type.dart';
import '../l10n/app_localizations.dart';
import '../models/task_item.dart';
import '../services/workspace_manager.dart';
import 'task_editor_screen.dart';

const List<Color> _palette = [
  Color(0xFFFF5A5F),
  Color(0xFF4C8DF5),
  Color(0xFF35C46B),
  Color(0xFFF2A33C),
  Color(0xFF2BB0A6),
  Color(0xFF8E9199),
];

String _bytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) {
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class PieSlice {
  const PieSlice(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class WorkspaceStatsScreen extends StatelessWidget {
  const WorkspaceStatsScreen({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final wm = context.watch<WorkspaceManager>();
    final ws = wm.workspaceById(workspaceId);
    if (ws == null) {
      return Scaffold(appBar: AppBar(title: Text(l.statistics)));
    }

    final files = wm.allFiles(workspaceId);
    final tasks = wm.allTasks(workspaceId);
    final notes = wm.noteCount(workspaceId);
    final totalSize = files.fold<int>(0, (s, f) => s + f.size);

    final content = <PieSlice>[
      PieSlice(l.files, files.length, _palette[0]),
      PieSlice(l.notes, notes, _palette[1]),
      PieSlice(l.tasks, tasks.length, _palette[2]),
    ];

    final statusSlices = [
      for (final s in TaskStatus.values)
        PieSlice(taskStatusLabel(l, s),
            tasks.where((t) => t.status == s).length, taskStatusColor(s)),
    ];
    final donePct =
        tasks.isEmpty ? 0 : (tasks.where((t) => t.done).length * 100 / tasks.length).round();

    int typeCount(MediaType t) =>
        files.where((f) => mediaTypeFromName(f.name) == t).length;
    final typeSlices = [
      PieSlice(l.images, typeCount(MediaType.image), _palette[0]),
      PieSlice(l.videos, typeCount(MediaType.video), _palette[1]),
      PieSlice(l.audio, typeCount(MediaType.audio), _palette[2]),
      PieSlice(l.otherFiles, typeCount(MediaType.other), _palette[5]),
    ];

    final cards = <Widget>[
      _StatTiles(
        members: ws.members.length,
        files: files.length,
        totalSize: _bytes(totalSize),
        notes: notes,
      ),
      _ChartCard(
        title: l.content,
        centerTop: '${files.length + notes + tasks.length}',
        centerBottom: l.overview,
        slices: content,
      ),
      _ChartCard(
        title: l.taskStatus,
        centerTop: '$donePct%',
        centerBottom: l.statusDone,
        slices: statusSlices,
      ),
      _ChartCard(
        title: l.byType,
        centerTop: '${files.length}',
        centerBottom: l.files,
        slices: typeSlices,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.statistics)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const maxContent = 980.0;
          final avail = math.min(constraints.maxWidth, maxContent);
          final wide = avail >= 720;
          final cardW = wide ? (avail - 48) / 2 : avail - 32;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxContent),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final c in cards) SizedBox(width: cardW, child: c),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatTiles extends StatelessWidget {
  const _StatTiles({
    required this.members,
    required this.files,
    required this.totalSize,
    required this.notes,
  });
  final int members;
  final int files;
  final String totalSize;
  final int notes;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          _tile(context, Icons.group_rounded, '$members', l.members),
          _tile(context, Icons.insert_drive_file_rounded, '$files', l.files),
          _tile(context, Icons.sd_storage_rounded, totalSize, l.totalSize),
          _tile(context, Icons.sticky_note_2_rounded, '$notes', l.notes),
        ],
      ),
    );
  }

  Widget _tile(
      BuildContext context, IconData icon, String value, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.centerTop,
    required this.centerBottom,
    required this.slices,
  });
  final String title;
  final String centerTop;
  final String centerBottom;
  final List<PieSlice> slices;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    final total = slices.fold<int>(0, (s, e) => s + e.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(120, 120),
                      painter: _DonutPainter(
                          slices, scheme.surfaceContainerHighest),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(centerTop,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800)),
                        Text(centerBottom,
                            style: TextStyle(
                                fontSize: 10,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in slices)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                  color: s.color,
                                  borderRadius: BorderRadius.circular(3)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(s.label,
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(
                              total == 0
                                  ? '0'
                                  : '${s.value} · ${(s.value * 100 / total).round()}%',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.emptyColor);
  final List<PieSlice> slices;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke,
        size.height - stroke);
    final total = slices.fold<int>(0, (s, e) => s + e.value);

    if (total == 0) {
      canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = emptyColor,
      );
      return;
    }

    var start = -math.pi / 2;
    for (final s in slices) {
      if (s.value == 0) continue;
      final sweep = (s.value / total) * 2 * math.pi;
      canvas.drawArc(
        rect,
        start,
        sweep - 0.02, // tiny gap between slices
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = s.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}
