import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/media_type.dart';
import '../core/platform.dart';
import '../l10n/app_localizations.dart';
import '../models/file_record.dart';
import '../models/file_transfer.dart';
import '../models/folder.dart';
import '../models/note.dart';
import '../models/task_item.dart';
import '../models/workspace.dart';
import '../services/file_transfer_manager.dart';
import '../services/workspace_manager.dart';
import '../state/app_controller.dart';
import 'brand/theme.dart';
import 'media/media_viewer.dart';
import 'note_editor_screen.dart';
import 'task_editor_screen.dart';
import 'widgets/device_card.dart';
import 'widgets/speed_dial.dart';
import 'widgets/text_prompt_dialog.dart';
import 'window/top_bar.dart';
import 'workspace_settings_screen.dart';
import 'workspace_stats_screen.dart';

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) {
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

enum _Seg { files, notes, tasks }

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  String? _folderId;
  _Seg _seg = _Seg.files;
  bool _grid = false;
  bool _board = false;
  bool _dragging = false;

  @override
  void dispose() {
    if (isDesktopWindowing) workspaceTopTitle.value = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final wm = context.watch<WorkspaceManager>();
    final app = context.watch<AppController>();
    final ftm = context.watch<FileTransferManager>();
    final ws = wm.workspaceById(widget.workspaceId);

    if (ws == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) nav.pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    if (_folderId != null && wm.folderById(_folderId!) == null) {
      _folderId = null;
    }

    final path = _pathTo(wm, _folderId);

    // On desktop the workspace name lives in the custom top window bar,
    // freeing up the app-bar row of screen space.
    if (isDesktopWindowing && workspaceTopTitle.value != ws.name) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => workspaceTopTitle.value = ws.name);
    }

    return Scaffold(
      appBar: isDesktopWindowing ? null : AppBar(title: Text(ws.name)),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: SpeedDial(
        actions: [
          SpeedDialAction(
              icon: Icons.upload_file_rounded,
              label: l.sendFile,
              onTap: () {
                _showSegment(_Seg.files);
                _pickAndSend(ws);
              }),
          SpeedDialAction(
              icon: Icons.create_new_folder_rounded,
              label: l.newFolder,
              onTap: () {
                _showSegment(_Seg.files);
                _createFolder(ws.id);
              }),
          SpeedDialAction(
              icon: Icons.note_add_rounded,
              label: l.addNote,
              onTap: () {
                _showSegment(_Seg.notes);
                _openNoteEditor(ws.id);
              }),
          SpeedDialAction(
              icon: Icons.add_task_rounded,
              label: l.addTask,
              onTap: () {
                _showSegment(_Seg.tasks);
                _openTaskEditor(ws.id);
              }),
        ],
      ),
      body: _dropPasteWrap(
        ws,
        ftm,
        SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 82,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _MembersStrip(
                        workspace: ws,
                        myId: app.me.deviceId,
                        onAdd: () => _addDeviceSheet(ws)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12, left: 8),
                    child: _FilterBlock(
                      seg: _seg,
                      grid: _grid,
                      board: _board,
                      onSeg: (s) => setState(() => _seg = s),
                      onToggleGrid: () => setState(() => _grid = !_grid),
                      onToggleBoard: () => setState(() => _board = !_board),
                      onStats: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              WorkspaceStatsScreen(workspaceId: ws.id),
                        ),
                      ),
                      onSettings: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              WorkspaceSettingsScreen(workspaceId: ws.id),
                        ),
                      ),
                      onAddDevice: () => _addDeviceSheet(ws),
                      onLeave: () async {
                        await context
                            .read<WorkspaceManager>()
                            .leaveWorkspace(ws.id);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
            _Breadcrumb(
              path: path,
              onTap: (id) => setState(() => _folderId = id),
            ),
            Expanded(child: _buildSegment(ws, wm, ftm)),
          ],
        ),
      )),
    );
  }

  /// Wraps the workspace body so files can be dropped in from the OS or pasted
  /// with Ctrl+V, sending them into the current folder.
  Widget _dropPasteWrap(
      Workspace ws, FileTransferManager ftm, Widget child) {
    // File drag-and-drop from the OS and Ctrl+V paste only exist on desktop.
    // On mobile these wrappers add a focus/shortcuts subtree that can trip a
    // framework assertion when the screen mounts and unmounts in the same
    // frame (e.g. a workspace that gets dissolved right as it opens), so skip
    // them entirely there.
    if (!isDesktopWindowing) return child;
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        for (final f in detail.files) {
          ftm.sendFile(ws, File(f.path), folderId: _folderId);
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): () =>
              _pasteFiles(ws),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              child,
              if (_dragging)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: scheme.primary, width: 2),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.file_download_rounded,
                                size: 48, color: scheme.primary),
                            const SizedBox(height: 8),
                            Text(l.dropToSend,
                                style: TextStyle(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pasteFiles(Workspace ws) async {
    final ftm = context.read<FileTransferManager>();
    final files = await Pasteboard.files();
    if (files.isNotEmpty) {
      for (final path in files) {
        await ftm.sendFile(ws, File(path), folderId: _folderId);
      }
      return;
    }
    // Fall back to a pasted image (e.g. a screenshot).
    final image = await Pasteboard.image;
    if (image != null) {
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/pasted_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(image);
      await ftm.sendFile(ws, file, folderId: _folderId);
    }
  }

  Widget _buildSegment(
      Workspace ws, WorkspaceManager wm, FileTransferManager ftm) {
    final l = AppLocalizations.of(context);
    switch (_seg) {
      case _Seg.files:
        final subfolders = wm.foldersIn(ws.id, _folderId);
        final files = wm.filesIn(ws.id, _folderId);
        final active = ftm
            .transfersFor(ws.id)
            .where((t) => t.isActive || t.status == TransferStatus.failed)
            .toList();
        if (subfolders.isEmpty && files.isEmpty && active.isEmpty) {
          return _EmptyState(icon: Icons.folder_open_rounded, title: l.emptyFolderTitle, hint: l.emptyFolderHint);
        }
        if (_grid) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final t in active) _TransferTile(transfer: t),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final f in subfolders)
                      _GridTile.folder(folder: f, onOpen: () => setState(() => _folderId = f.id), onDelete: () => _confirmDeleteFolder(f), onRename: () => _renameFolder(f)),
                    for (final f in files)
                      _GridTile.file(record: f, onDelete: () => _confirmDeleteFile(f), onShare: () => _share(f)),
                  ],
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final t in active) _TransferTile(transfer: t),
            for (final f in subfolders)
              _FolderTile(folder: f, onOpen: () => setState(() => _folderId = f.id), onDelete: () => _confirmDeleteFolder(f), onRename: () => _renameFolder(f)),
            for (final f in files)
              _FileTile(record: f, onDelete: () => _confirmDeleteFile(f), onShare: () => _share(f)),
          ],
        );
      case _Seg.notes:
        final notes = wm.notesIn(ws.id, _folderId);
        if (notes.isEmpty) {
          return _EmptyState(icon: Icons.sticky_note_2_outlined, title: l.noNotes, hint: l.emptyFolderHint);
        }
        if (_grid) {
          return LayoutBuilder(
            builder: (context, c) {
              final cols = (c.maxWidth / 240).floor().clamp(1, 5);
              final tileW = (c.maxWidth - 32 - 12 * (cols - 1)) / cols;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final n in notes)
                      _NoteGridCard(
                        note: n,
                        width: tileW,
                        onEdit: () => _editNote(n),
                        onCopy: () => _copy(n.text),
                        onDelete: () => wm.deleteNote(n.id),
                      ),
                  ],
                ),
              );
            },
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final n in notes)
              _NoteCard(note: n, onEdit: () => _editNote(n), onCopy: () => _copy(n.text), onDelete: () => wm.deleteNote(n.id)),
          ],
        );
      case _Seg.tasks:
        final tasks = wm.tasksIn(ws.id, _folderId);
        if (_board) {
          return _KanbanBoard(
            tasks: tasks,
            onOpen: (t) => _openTaskEditor(ws.id, task: t),
            onSetStatus: (id, s) => wm.setTaskStatus(id, s),
            onAdd: (s) => _openTaskEditor(ws.id, initialStatus: s),
          );
        }
        if (tasks.isEmpty) {
          return _EmptyState(icon: Icons.checklist_rounded, title: l.noTasks, hint: l.emptyFolderHint);
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final t in tasks)
              _TaskTile(
                task: t,
                onToggle: () => wm.toggleTask(t.id),
                onOpen: () => _openTaskEditor(ws.id, task: t),
                onCopy: () => _copy(t.text),
                onDelete: () => wm.deleteTask(t.id),
              ),
          ],
        );
    }
  }

  /// Switch the visible segment (files / notes / tasks) so a just-added item is
  /// actually shown instead of silently landing on a hidden tab.
  void _showSegment(_Seg seg) {
    if (_seg != seg) setState(() => _seg = seg);
  }

  void _openNoteEditor(String workspaceId, {Note? note}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NoteEditorScreen(
        workspaceId: workspaceId,
        folderId: _folderId,
        note: note,
      ),
    ));
  }

  List<Folder> _pathTo(WorkspaceManager wm, String? folderId) {
    final chain = <Folder>[];
    var id = folderId;
    while (id != null) {
      final f = wm.folderById(id);
      if (f == null) break;
      chain.insert(0, f);
      id = f.parentId;
    }
    return chain;
  }

  Future<void> _share(FileRecord record) async {
    if (!File(record.path).existsSync()) return;
    await Share.shareXFiles([XFile(record.path)]);
  }

  void _copy(String text) {
    final l = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.copied)));
  }

  Future<void> _pickAndSend(Workspace ws) async {
    final l = AppLocalizations.of(context);
    final ftm = context.read<FileTransferManager>();
    final messenger = ScaffoldMessenger.of(context);
    final noMembers =
        ws.others(context.read<AppController>().me.deviceId).isEmpty;
    final result = await FilePicker.platform.pickFiles();
    final p = result?.files.single.path;
    if (p == null) return;
    await ftm.sendFile(ws, File(p), folderId: _folderId);
    if (noMembers) {
      messenger.showSnackBar(SnackBar(content: Text(l.noDevicesToAdd)));
    }
  }

  void _editNote(Note note) =>
      _openNoteEditor(note.workspaceId, note: note);

  void _openTaskEditor(String workspaceId,
      {TaskItem? task, TaskStatus initialStatus = TaskStatus.todo}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TaskEditorScreen(
        workspaceId: workspaceId,
        folderId: _folderId,
        task: task,
        initialStatus: initialStatus,
      ),
    ));
  }

  Future<void> _createFolder(String workspaceId) async {
    final l = AppLocalizations.of(context);
    final wm = context.read<WorkspaceManager>();
    final name = await _promptText(l.newFolder, l.folderName);
    if (name == null || name.trim().isEmpty) return;
    wm.createFolder(workspaceId, _folderId, name);
  }

  Future<void> _renameFolder(Folder folder) async {
    final l = AppLocalizations.of(context);
    final wm = context.read<WorkspaceManager>();
    final name =
        await _promptText(l.rename, l.folderName, initial: folder.name);
    if (name == null || name.trim().isEmpty) return;
    wm.renameFolder(folder.id, name);
  }

  Future<void> _confirmDeleteFolder(Folder folder) async {
    final l = AppLocalizations.of(context);
    final wm = context.read<WorkspaceManager>();
    if (await _confirm(l.deleteFolderConfirm)) wm.deleteFolder(folder.id);
  }

  Future<void> _confirmDeleteFile(FileRecord record) async {
    final l = AppLocalizations.of(context);
    final wm = context.read<WorkspaceManager>();
    if (await _confirm(l.deleteFileConfirm)) wm.deleteFileRecord(record.id);
  }

  Future<String?> _promptText(String title, String label,
      {String initial = ''}) {
    final l = AppLocalizations.of(context);
    return promptText(context,
        title: title, label: label, confirmLabel: l.save, initial: initial);
  }

  Future<bool> _confirm(String message) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _addDeviceSheet(Workspace ws) async {
    final l = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Consumer<AppController>(
          builder: (context, app, _) {
            final candidates = app.peers
                .where((p) => !ws.members.any((m) => m.id == p.id))
                .toList();
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text(l.addDevice,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (candidates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Text(l.noDevicesToAdd,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    )
                  else
                    ...candidates.map(
                      (p) => ListTile(
                        leading: Icon(platformIcon(p.platform)),
                        title: Text(p.name),
                        subtitle: Text('${p.host}:${p.port}'),
                        trailing: FilledButton(
                          onPressed: () async {
                            await context
                                .read<WorkspaceManager>()
                                .invite(ws.id, p.id, p.name, p.platform);
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l.inviteSent)),
                              );
                            }
                          },
                          child: Text(l.invite),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// --- Members strip ----------------------------------------------------------

class _MembersStrip extends StatelessWidget {
  const _MembersStrip(
      {required this.workspace, required this.myId, required this.onAdd});
  final Workspace workspace;
  final String myId;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final app = context.watch<AppController>();
    final scheme = Theme.of(context).colorScheme;
    final brand = BrandColors.of(context);

    return SizedBox(
      height: 82,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        children: [
          for (final m in workspace.members)
            _chip(context, m, app, scheme, brand, l),
          SizedBox(
            width: 64,
            child: Column(
              children: [
                InkWell(
                  onTap: onAdd,
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.surfaceContainerHighest,
                    child: Icon(Icons.add_rounded,
                        color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 4),
                Text(l.addDevice,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, WorkspaceMember m, AppController app,
      ColorScheme scheme, BrandColors brand, AppLocalizations l) {
    final peer = app.peerById(m.id);
    final online = m.id == myId ? true : (peer?.isOnline ?? false);
    final name = m.id == myId ? l.you : (peer?.name ?? m.name);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: online
                      ? scheme.primary.withValues(alpha: 0.15)
                      : scheme.surfaceContainerHighest,
                  child: Icon(platformIcon(m.platform),
                      color:
                          online ? scheme.primary : scheme.onSurfaceVariant),
                ),
                if (online)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: brand.online,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(name,
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// --- Filter block -----------------------------------------------------------

class _FilterBlock extends StatelessWidget {
  const _FilterBlock({
    required this.seg,
    required this.grid,
    required this.board,
    required this.onSeg,
    required this.onToggleGrid,
    required this.onToggleBoard,
    required this.onStats,
    required this.onSettings,
    required this.onAddDevice,
    required this.onLeave,
  });

  final _Seg seg;
  final bool grid;
  final bool board;
  final ValueChanged<_Seg> onSeg;
  final VoidCallback onToggleGrid;
  final VoidCallback onToggleBoard;
  final VoidCallback onStats;
  final VoidCallback onSettings;
  final VoidCallback onAddDevice;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segBtn(context, _Seg.files, Icons.folder_rounded, l.files),
          _segBtn(context, _Seg.notes, Icons.sticky_note_2_rounded, l.notes),
          _segBtn(context, _Seg.tasks, Icons.checklist_rounded, l.tasks),
          if (seg == _Seg.files || seg == _Seg.notes) ...[
            _divider(scheme),
            IconButton(
              tooltip: grid ? l.listView : l.gridView,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              onPressed: onToggleGrid,
            ),
          ],
          if (seg == _Seg.tasks) ...[
            _divider(scheme),
            IconButton(
              tooltip: board ? l.listView : l.board,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                board ? Icons.view_list_rounded : Icons.view_kanban_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              onPressed: onToggleBoard,
            ),
          ],
          _divider(scheme),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                size: 20, color: scheme.onSurfaceVariant),
            onSelected: (v) {
              switch (v) {
                case 'stats':
                  onStats();
                case 'settings':
                  onSettings();
                case 'add':
                  onAddDevice();
                case 'leave':
                  onLeave();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'stats',
                child: Row(children: [
                  const Icon(Icons.pie_chart_outline_rounded, size: 20),
                  const SizedBox(width: 12),
                  Text(l.statistics),
                ]),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(children: [
                  const Icon(Icons.settings_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(l.workspaceSettings),
                ]),
              ),
              PopupMenuItem(
                value: 'add',
                child: Row(children: [
                  const Icon(Icons.person_add_alt_1_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(l.addDevice),
                ]),
              ),
              PopupMenuItem(
                value: 'leave',
                child: Row(children: [
                  const Icon(Icons.logout_rounded, size: 20),
                  const SizedBox(width: 12),
                  Text(l.leave),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme scheme) => Container(
        width: 1,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        color: scheme.outlineVariant.withValues(alpha: 0.6),
      );

  Widget _segBtn(
      BuildContext context, _Seg value, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    final selected = seg == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Material(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSeg(value),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: selected ? 12 : 9, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 18,
                      color: selected
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Text(label,
                        style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Breadcrumb -------------------------------------------------------------

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.path, required this.onTap});
  final List<Folder> path;
  final ValueChanged<String?> onTap;

  @override
  Widget build(BuildContext context) {
    // At the workspace root there's nothing to show — the name already lives in
    // the top bar, so we keep the space free.
    if (path.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final crumbs = <Widget>[
      InkWell(
        onTap: () => onTap(null),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.home_rounded,
              size: 18, color: scheme.onSurfaceVariant),
        ),
      ),
    ];
    for (var i = 0; i < path.length; i++) {
      crumbs.add(Icon(Icons.chevron_right_rounded,
          size: 18, color: scheme.onSurfaceVariant));
      final f = path[i];
      crumbs.add(_crumb(context, f.name, () => onTap(f.id),
          isLast: i == path.length - 1));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: crumbs),
      ),
    );
  }

  Widget _crumb(BuildContext context, String label, VoidCallback onTap,
      {required bool isLast}) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: isLast ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
            color: isLast ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// --- List tiles -------------------------------------------------------------

class _FolderTile extends StatelessWidget {
  const _FolderTile(
      {required this.folder,
      required this.onOpen,
      required this.onDelete,
      required this.onRename});
  final Folder folder;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _iconBox(scheme, Icons.folder_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(folder.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'rename' ? onRename() : onDelete(),
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'rename', child: Text(l.rename)),
                    PopupMenuItem(value: 'delete', child: Text(l.delete)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile(
      {required this.record, required this.onDelete, required this.onShare});
  final FileRecord record;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final exists = File(record.path).existsSync();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: exists ? () => _open(context) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _fileLeading(record, scheme, exists, 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                        '${formatBytes(record.size)}'
                        '${record.incoming && record.peerName.isNotEmpty ? ' · ${record.peerName}' : ''}',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'share' ? onShare() : onDelete(),
                  itemBuilder: (context) => [
                    if (exists)
                      PopupMenuItem(value: 'share', child: Text(l.share)),
                    PopupMenuItem(value: 'delete', child: Text(l.delete)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    if (!openMedia(context, record.path, record.name)) {
      OpenFilex.open(record.path);
    }
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.transfer});
  final FileTransfer transfer;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = transfer;
    final failed = t.status == TransferStatus.failed;
    final color = failed ? scheme.error : scheme.primary;
    final label = failed ? l.failed : (t.isIncoming ? l.receiving : l.sending);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                    failed
                        ? Icons.error_rounded
                        : (t.isIncoming
                            ? Icons.download_rounded
                            : Icons.upload_rounded),
                    color: color,
                    size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${t.fileName}  ·  $label',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (t.isActive) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: t.size > 0 ? t.progress : null,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(t.progress * 100).toStringAsFixed(0)}%  '
                '(${formatBytes(t.transferred)} / ${formatBytes(t.size)})',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --- Grid tiles -------------------------------------------------------------

class _GridTile extends StatelessWidget {
  const _GridTile._({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.onMenu,
    this.imagePath,
    this.menuItems = const [],
  });

  factory _GridTile.folder({
    required Folder folder,
    required VoidCallback onOpen,
    required VoidCallback onDelete,
    required VoidCallback onRename,
  }) =>
      _GridTile._(
        icon: Icons.folder_rounded,
        label: folder.name,
        onTap: (_) => onOpen(),
        onMenu: (v) => v == 'rename' ? onRename() : onDelete(),
        menuItems: const ['rename', 'delete'],
      );

  factory _GridTile.file({
    required FileRecord record,
    required VoidCallback onDelete,
    required VoidCallback onShare,
  }) {
    final mt = mediaTypeFromName(record.name);
    final exists = File(record.path).existsSync();
    return _GridTile._(
      icon: switch (mt) {
        MediaType.video => Icons.play_circle_fill_rounded,
        MediaType.audio => Icons.music_note_rounded,
        MediaType.image => Icons.image_rounded,
        MediaType.other => Icons.insert_drive_file_rounded,
      },
      label: record.name,
      imagePath: exists && mt == MediaType.image ? record.path : null,
      onTap: exists
          ? (BuildContext context) {
              if (!openMedia(context, record.path, record.name)) {
                OpenFilex.open(record.path);
              }
            }
          : null,
      onMenu: (v) => v == 'share' ? onShare() : onDelete(),
      menuItems: exists ? const ['share', 'delete'] : const ['delete'],
    );
  }

  final IconData icon;
  final String label;
  final String? imagePath;
  final void Function(BuildContext)? onTap;
  final ValueChanged<String> onMenu;
  final List<String> menuItems;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final width = (MediaQuery.of(context).size.width - 12 * 2 - 12) / 2;
    return SizedBox(
      width: width.clamp(120, 260),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null ? null : () => onTap!(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.4,
                child: imagePath != null
                    ? Image.file(File(imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(scheme))
                    : _placeholder(scheme),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      onSelected: onMenu,
                      itemBuilder: (context) => [
                        for (final m in menuItems)
                          PopupMenuItem(
                              value: m,
                              child: Text(m == 'share'
                                  ? l.share
                                  : m == 'rename'
                                      ? l.rename
                                      : l.delete)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Container(
        color: scheme.primary.withValues(alpha: 0.10),
        child: Icon(icon, size: 40, color: scheme.primary),
      );
}

// --- Notes & tasks ----------------------------------------------------------

class _NoteCard extends StatelessWidget {
  const _NoteCard(
      {required this.note,
      required this.onEdit,
      required this.onCopy,
      required this.onDelete});
  final Note note;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sticky_note_2_rounded,
                        size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(note.title,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      tooltip: l.copy,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: onCopy,
                    ),
                    IconButton(
                      tooltip: l.delete,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      onPressed: onDelete,
                    ),
                  ],
                ),
                if (note.text.trim().contains('\n') ||
                    note.text.trim().length > note.title.length) ...[
                  const SizedBox(height: 4),
                  Text(
                    note.text.trim(),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact sticky-note tile for the notes grid view.
class _NoteGridCard extends StatelessWidget {
  const _NoteGridCard({
    required this.note,
    required this.width,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
  });
  final Note note;
  final double width;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final body = note.text.trim();
    final hasBody = body.isNotEmpty && body != note.title;
    return SizedBox(
      width: width,
      child: Material(
        color: Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.06), scheme.surfaceContainerHigh),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Container(
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 240),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sticky_note_2_rounded,
                        size: 16, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (hasBody) ...[
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      body,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.3),
                      overflow: TextOverflow.fade,
                    ),
                  ),
                ] else
                  const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: l.copy,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      icon: const Icon(Icons.copy_rounded, size: 17),
                      onPressed: onCopy,
                    ),
                    IconButton(
                      tooltip: l.delete,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      icon: const Icon(Icons.delete_outline_rounded, size: 17),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onOpen,
    required this.onCopy,
    required this.onDelete,
  });
  final TaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            child: Row(
              children: [
                Checkbox(value: task.done, onChanged: (_) => onToggle()),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.text,
                        style: TextStyle(
                          decoration:
                              task.done ? TextDecoration.lineThrough : null,
                          color: task.done ? scheme.onSurfaceVariant : null,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.category.isNotEmpty ||
                          task.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              if (task.category.isNotEmpty)
                                _CategoryChip(label: task.category),
                              if (task.description.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(
                                      left: task.category.isNotEmpty ? 8 : 0),
                                  child: Icon(Icons.notes_rounded,
                                      size: 14,
                                      color: scheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.copy,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: onCopy,
                ),
                IconButton(
                  tooltip: l.delete,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: scheme.primary,
              fontWeight: FontWeight.w600)),
    );
  }
}

// --- Kanban board -----------------------------------------------------------

class _KanbanBoard extends StatelessWidget {
  const _KanbanBoard({
    required this.tasks,
    required this.onOpen,
    required this.onSetStatus,
    required this.onAdd,
  });

  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onOpen;
  final void Function(String id, TaskStatus status) onSetStatus;
  final ValueChanged<TaskStatus> onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
      children: [
        for (final status in TaskStatus.values)
          _KanbanColumn(
            status: status,
            tasks: tasks.where((t) => t.status == status).toList(),
            onOpen: onOpen,
            onDropTask: (id) => onSetStatus(id, status),
            onAdd: () => onAdd(status),
          ),
      ],
    );
  }
}

class _KanbanColumn extends StatefulWidget {
  const _KanbanColumn({
    required this.status,
    required this.tasks,
    required this.onOpen,
    required this.onDropTask,
    required this.onAdd,
  });

  final TaskStatus status;
  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onOpen;
  final ValueChanged<String> onDropTask;
  final VoidCallback onAdd;

  @override
  State<_KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends State<_KanbanColumn> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = taskStatusColor(widget.status);
    final width = math.min(300.0, MediaQuery.of(context).size.width - 60);

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) {
        setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (d) {
        setState(() => _hovering = false);
        widget.onDropTask(d.data);
      },
      builder: (context, candidate, rejected) {
        return Container(
          width: width,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: _hovering
                ? color.withValues(alpha: 0.12)
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _hovering ? color : scheme.outlineVariant,
                width: _hovering ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
                child: Row(
                  children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(taskStatusLabel(l, widget.status),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Text('${widget.tasks.length}',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      onPressed: widget.onAdd,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  children: [
                    for (final t in widget.tasks)
                      _TaskCard(task: t, onOpen: () => widget.onOpen(t)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onOpen});
  final TaskItem task;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.text,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(task.description,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              if (task.category.isNotEmpty) ...[
                const SizedBox(height: 8),
                _CategoryChip(label: task.category),
              ],
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LongPressDraggable<String>(
        data: task.id,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.9,
            child: SizedBox(width: 260, child: card),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: card),
        child: card,
      ),
    );
  }
}

// --- Shared bits ------------------------------------------------------------

Widget _iconBox(ColorScheme scheme, IconData icon) => Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: scheme.primary, size: 22),
    );

Widget _fileLeading(
    FileRecord record, ColorScheme scheme, bool exists, double size) {
  final mt = mediaTypeFromName(record.name);
  if (exists && mt == MediaType.image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(File(record.path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _iconBox(scheme, Icons.image_rounded)),
    );
  }
  final icon = switch (mt) {
    MediaType.video => Icons.play_circle_fill_rounded,
    MediaType.audio => Icons.music_note_rounded,
    MediaType.image => Icons.image_rounded,
    MediaType.other => Icons.insert_drive_file_rounded,
  };
  return _iconBox(scheme, icon);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.title, required this.hint});
  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 56,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(hint,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

