import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/task_item.dart';
import '../services/workspace_manager.dart';

String taskStatusLabel(AppLocalizations l, TaskStatus s) => switch (s) {
      TaskStatus.todo => l.statusTodo,
      TaskStatus.doing => l.statusDoing,
      TaskStatus.done => l.statusDone,
    };

Color taskStatusColor(TaskStatus s) => switch (s) {
      TaskStatus.todo => const Color(0xFF8E9199),
      TaskStatus.doing => const Color(0xFFF2A33C),
      TaskStatus.done => const Color(0xFF35C46B),
    };

/// Full-screen editor to create or edit a task with a status, category and
/// description.
class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({
    super.key,
    required this.workspaceId,
    required this.folderId,
    this.task,
    this.initialStatus = TaskStatus.todo,
  });

  final String workspaceId;
  final String? folderId;
  final TaskItem? task;
  final TaskStatus initialStatus;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _category;
  late final TextEditingController _desc;
  late TaskStatus _status;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.text ?? '');
    _category = TextEditingController(text: t?.category ?? '');
    _desc = TextEditingController(text: t?.description ?? '');
    _status = t?.status ?? widget.initialStatus;
  }

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final wm = context.read<WorkspaceManager>();
    if (title.isEmpty) {
      if (_editing) wm.deleteTask(widget.task!.id);
      Navigator.of(context).pop();
      return;
    }
    if (_editing) {
      wm.updateTask(widget.task!.id,
          text: title,
          category: _category.text,
          description: _desc.text,
          status: _status);
    } else {
      wm.addTask(widget.workspaceId, widget.folderId, title,
          category: _category.text,
          description: _desc.text,
          status: _status);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l.taskText : l.newTask),
        actions: [
          if (_editing)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                context.read<WorkspaceManager>().deleteTask(widget.task!.id);
                Navigator.of(context).pop();
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(l.save),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _title,
            autofocus: !_editing,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: l.taskText,
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 16),
          Text(l.status.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          SegmentedButton<TaskStatus>(
            segments: [
              for (final s in TaskStatus.values)
                ButtonSegment(value: s, label: Text(taskStatusLabel(l, s))),
            ],
            selected: {_status},
            onSelectionChanged: (v) => setState(() => _status = v.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _category,
            decoration: InputDecoration(
              labelText: l.category,
              prefixIcon: const Icon(Icons.label_outline_rounded),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _desc,
            minLines: 4,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: l.description,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
