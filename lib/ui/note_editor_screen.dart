import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/note.dart';
import '../services/workspace_manager.dart';

/// A full-screen note editor for creating or editing a note.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.workspaceId,
    required this.folderId,
    this.note,
  });

  final String workspaceId;
  final String? folderId;
  final Note? note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _controller;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note?.text ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    final wm = context.read<WorkspaceManager>();
    if (_isEditing) {
      if (text.isEmpty) {
        wm.deleteNote(widget.note!.id);
      } else {
        wm.updateNote(widget.note!.id, text);
      }
    } else if (text.isNotEmpty) {
      wm.addNote(widget.workspaceId, widget.folderId, text);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l.edit : l.addNote),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: l.copy,
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _controller.text));
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l.copied)));
              },
            ),
          if (_isEditing)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                context.read<WorkspaceManager>().deleteNote(widget.note!.id);
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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: TextField(
          controller: _controller,
          autofocus: true,
          expands: true,
          maxLines: null,
          minLines: null,
          textAlignVertical: TextAlignVertical.top,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(fontSize: 16, height: 1.4),
          decoration: InputDecoration(
            hintText: l.noteText,
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
