import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/protocol/wire_message.dart';
import '../models/file_record.dart';
import '../models/folder.dart';
import '../models/note.dart';
import '../models/task_item.dart';
import '../models/workspace.dart';
import 'database.dart';
import 'identity_service.dart';
import 'network_manager.dart';
import 'transport_service.dart';

/// Owns all workspace *content* — memberships, the folder tree and the file
/// library — and keeps it persisted (via [AppDatabase]) and synchronised across
/// devices. Membership is owner-authoritative; folders use last-write-wins
/// broadcast; file records arrive with their transfers.
class WorkspaceManager extends ChangeNotifier {
  WorkspaceManager(this._identity, this._network, this._db) {
    _sub = _network.control.listen(_onControl);
    _workspaces.addAll(_db.loadWorkspaces());
    _folders.addAll(_db.loadFolders());
    _files.addAll(_db.loadFiles());
    _notes.addAll(_db.loadNotes());
    _tasks.addAll(_db.loadTasks());
  }

  static const Uuid _uuid = Uuid();

  final IdentityService _identity;
  final NetworkManager _network;
  final AppDatabase _db;
  late final StreamSubscription<InboundMessage> _sub;

  final List<Workspace> _workspaces = [];
  final List<WorkspaceInvite> _pendingInvites = [];
  final List<Folder> _folders = [];
  final List<FileRecord> _files = [];
  final List<Note> _notes = [];
  final List<TaskItem> _tasks = [];

  List<Workspace> get workspaces => List.unmodifiable(_workspaces);
  List<WorkspaceInvite> get pendingInvites => List.unmodifiable(_pendingInvites);

  WorkspaceMember get _me => WorkspaceMember(
        id: _identity.identity.deviceId,
        name: _identity.identity.name,
        platform: _identity.identity.platform,
      );

  int get _now => DateTime.now().millisecondsSinceEpoch;

  Workspace? workspaceById(String id) {
    for (final w in _workspaces) {
      if (w.id == id) return w;
    }
    return null;
  }

  // --- Folders (read) -------------------------------------------------------

  /// Direct child folders of [parentId] (null = workspace root).
  List<Folder> foldersIn(String workspaceId, String? parentId) {
    final list = _folders
        .where((f) => f.workspaceId == workspaceId && f.parentId == parentId)
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Folder? folderById(String id) {
    for (final f in _folders) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Files directly inside [folderId] (null = workspace root).
  List<FileRecord> filesIn(String workspaceId, String? folderId) {
    final list = _files
        .where((f) => f.workspaceId == workspaceId && f.folderId == folderId)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Note> notesIn(String workspaceId, String? folderId) {
    final list = _notes
        .where((n) => n.workspaceId == workspaceId && n.folderId == folderId)
        .toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<TaskItem> tasksIn(String workspaceId, String? folderId) {
    final list = _tasks
        .where((t) => t.workspaceId == workspaceId && t.folderId == folderId)
        .toList();
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1; // undone first
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  // Workspace-wide collections for the overview / statistics.
  int fileCount(String workspaceId) =>
      _files.where((f) => f.workspaceId == workspaceId).length;
  int noteCount(String workspaceId) =>
      _notes.where((n) => n.workspaceId == workspaceId).length;
  List<FileRecord> allFiles(String workspaceId) =>
      _files.where((f) => f.workspaceId == workspaceId).toList();
  List<TaskItem> allTasks(String workspaceId) =>
      _tasks.where((t) => t.workspaceId == workspaceId).toList();

  /// Renames a workspace (owner only) and syncs the new name to members.
  void renameWorkspace(String id, String name) {
    final idx = _workspaces.indexWhere((w) => w.id == id);
    if (idx < 0) return;
    final ws = _workspaces[idx];
    if (!ws.isOwner(_me.id)) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final updated = ws.copyWith(name: trimmed);
    _workspaces[idx] = updated;
    _db.upsertWorkspace(updated);
    notifyListeners();
    _broadcastSync(updated);
  }

  // --- Workspace actions ----------------------------------------------------

  Workspace createWorkspace(String name) {
    final trimmed = name.trim();
    final ws = Workspace(
      id: _uuid.v4(),
      name: trimmed.isEmpty ? 'Workspace' : trimmed,
      ownerId: _me.id,
      members: [_me],
    );
    _workspaces.add(ws);
    _db.upsertWorkspace(ws);
    notifyListeners();
    return ws;
  }

  Future<bool> invite(
    String workspaceId,
    String peerId,
    String peerName,
    String peerPlatform,
  ) async {
    final ws = workspaceById(workspaceId);
    if (ws == null) return false;
    if (ws.members.any((m) => m.id == peerId)) return false;
    return _network.sendControl(
      peerId,
      WireMessage(MsgType.workspaceInvite, {
        'from': _me.id,
        'fromName': _me.name,
        'workspace': ws.toJson(),
      }),
    );
  }

  Future<void> acceptInvite(WorkspaceInvite invite) async {
    final ws = invite.workspace;
    final members = List<WorkspaceMember>.from(ws.members);
    if (!members.any((m) => m.id == _me.id)) members.add(_me);
    final joined = ws.copyWith(members: members);
    _workspaces.add(joined);
    _db.upsertWorkspace(joined);
    _pendingInvites.removeWhere((i) => i.workspace.id == ws.id);
    notifyListeners();

    await _network.sendControl(
      invite.fromId,
      WireMessage(MsgType.workspaceInviteResponse, {
        'workspaceId': ws.id,
        'accepted': true,
        'member': _me.toJson(),
      }),
    );
  }

  Future<void> declineInvite(WorkspaceInvite invite) async {
    _pendingInvites.removeWhere((i) => i.workspace.id == invite.workspace.id);
    notifyListeners();
    await _network.sendControl(
      invite.fromId,
      WireMessage(MsgType.workspaceInviteResponse, {
        'workspaceId': invite.workspace.id,
        'accepted': false,
        'member': _me.toJson(),
      }),
    );
  }

  Future<void> leaveWorkspace(String id) async {
    final idx = _workspaces.indexWhere((w) => w.id == id);
    if (idx < 0) return;
    final ws = _workspaces[idx];

    if (ws.isOwner(_me.id)) {
      for (final m in ws.others(_me.id)) {
        _network.sendControl(
          m.id,
          WireMessage(MsgType.workspaceLeave,
              {'workspaceId': id, 'memberId': _me.id, 'ownerLeft': true}),
        );
      }
    } else {
      _network.sendControl(
        ws.ownerId,
        WireMessage(
            MsgType.workspaceLeave, {'workspaceId': id, 'memberId': _me.id}),
      );
    }

    _removeWorkspaceLocal(id);
    notifyListeners();
  }

  // --- Folder actions -------------------------------------------------------

  Folder createFolder(String workspaceId, String? parentId, String name) {
    final trimmed = name.trim();
    final folder = Folder(
      id: _uuid.v4(),
      workspaceId: workspaceId,
      parentId: parentId,
      name: trimmed.isEmpty ? 'Folder' : trimmed,
      createdAt: _now,
    );
    _folders.add(folder);
    _db.upsertFolder(folder);
    notifyListeners();
    _broadcastFolders(workspaceId);
    return folder;
  }

  void renameFolder(String folderId, String name) {
    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx < 0) return;
    final updated = _folders[idx].copyWith(name: name.trim());
    _folders[idx] = updated;
    _db.upsertFolder(updated);
    notifyListeners();
    _broadcastFolders(updated.workspaceId);
  }

  void deleteFolder(String folderId) {
    final folder = folderById(folderId);
    if (folder == null) return;
    final wsId = folder.workspaceId;

    final doomed = <String>{};
    void collect(String id) {
      doomed.add(id);
      for (final c in _folders.where((f) => f.parentId == id)) {
        collect(c.id);
      }
    }

    collect(folderId);

    // Reassign files under deleted folders up to the deleted folder's parent.
    for (var i = 0; i < _files.length; i++) {
      final fr = _files[i];
      if (fr.folderId != null && doomed.contains(fr.folderId)) {
        final moved = FileRecord(
          id: fr.id,
          workspaceId: fr.workspaceId,
          folderId: folder.parentId,
          name: fr.name,
          size: fr.size,
          path: fr.path,
          sha256: fr.sha256,
          incoming: fr.incoming,
          peerName: fr.peerName,
          createdAt: fr.createdAt,
        );
        _files[i] = moved;
        _db.upsertFile(moved);
      }
    }

    // Reassign notes/tasks under deleted folders up to the parent as well.
    for (var i = 0; i < _notes.length; i++) {
      final n = _notes[i];
      if (n.folderId != null && doomed.contains(n.folderId)) {
        final moved = Note(
          id: n.id,
          workspaceId: n.workspaceId,
          folderId: folder.parentId,
          text: n.text,
          createdAt: n.createdAt,
          updatedAt: n.updatedAt,
        );
        _notes[i] = moved;
        _db.upsertNote(moved);
      }
    }
    for (var i = 0; i < _tasks.length; i++) {
      final t = _tasks[i];
      if (t.folderId != null && doomed.contains(t.folderId)) {
        final moved = TaskItem(
          id: t.id,
          workspaceId: t.workspaceId,
          folderId: folder.parentId,
          text: t.text,
          status: t.status,
          category: t.category,
          description: t.description,
          createdAt: t.createdAt,
        );
        _tasks[i] = moved;
        _db.upsertTask(moved);
      }
    }

    _folders.removeWhere((f) => doomed.contains(f.id));
    for (final id in doomed) {
      _db.deleteFolder(id);
    }
    notifyListeners();
    _broadcastFolders(wsId);
    _broadcastNotes(wsId);
    _broadcastTasks(wsId);
  }

  // --- Files ----------------------------------------------------------------

  /// Called by the transfer manager when a file transfer completes.
  void addFile(FileRecord record) {
    _files.removeWhere((f) => f.id == record.id);
    _files.insert(0, record);
    _db.upsertFile(record);
    notifyListeners();
  }

  void deleteFileRecord(String id) {
    _files.removeWhere((f) => f.id == id);
    _db.deleteFile(id);
    notifyListeners();
  }

  // --- Notes ----------------------------------------------------------------

  Note addNote(String workspaceId, String? folderId, String text) {
    final note = Note(
      id: _uuid.v4(),
      workspaceId: workspaceId,
      folderId: folderId,
      text: text.trim(),
      createdAt: _now,
      updatedAt: _now,
    );
    _notes.add(note);
    _db.upsertNote(note);
    notifyListeners();
    _broadcastNotes(workspaceId);
    return note;
  }

  void updateNote(String id, String text) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final updated = _notes[idx].copyWith(text: text.trim(), updatedAt: _now);
    _notes[idx] = updated;
    _db.upsertNote(updated);
    notifyListeners();
    _broadcastNotes(updated.workspaceId);
  }

  void deleteNote(String id) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final wsId = _notes[idx].workspaceId;
    _notes.removeAt(idx);
    _db.deleteNote(id);
    notifyListeners();
    _broadcastNotes(wsId);
  }

  // --- Tasks ----------------------------------------------------------------

  TaskItem addTask(
    String workspaceId,
    String? folderId,
    String text, {
    String category = '',
    String description = '',
    TaskStatus status = TaskStatus.todo,
  }) {
    final task = TaskItem(
      id: _uuid.v4(),
      workspaceId: workspaceId,
      folderId: folderId,
      text: text.trim(),
      status: status,
      category: category.trim(),
      description: description.trim(),
      createdAt: _now,
    );
    _tasks.add(task);
    _db.upsertTask(task);
    notifyListeners();
    _broadcastTasks(workspaceId);
    return task;
  }

  void toggleTask(String id) {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = _tasks[idx];
    _applyTask(
        idx, t.copyWith(status: t.done ? TaskStatus.todo : TaskStatus.done));
  }

  void setTaskStatus(String id, TaskStatus status) {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    _applyTask(idx, _tasks[idx].copyWith(status: status));
  }

  void updateTask(
    String id, {
    String? text,
    String? category,
    String? description,
    TaskStatus? status,
  }) {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    _applyTask(
      idx,
      _tasks[idx].copyWith(
        text: text?.trim(),
        category: category?.trim(),
        description: description?.trim(),
        status: status,
      ),
    );
  }

  void _applyTask(int idx, TaskItem updated) {
    _tasks[idx] = updated;
    _db.upsertTask(updated);
    notifyListeners();
    _broadcastTasks(updated.workspaceId);
  }

  void deleteTask(String id) {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final wsId = _tasks[idx].workspaceId;
    _tasks.removeAt(idx);
    _db.deleteTask(id);
    notifyListeners();
    _broadcastTasks(wsId);
  }

  // --- Profile (name) sync --------------------------------------------------

  /// Broadcasts our current display name to every workspace member so their
  /// cached copies update automatically.
  void broadcastProfile() {
    final seen = <String>{};
    for (final ws in _workspaces) {
      for (final m in ws.others(_me.id)) {
        if (seen.add(m.id)) {
          _network.sendControl(
            m.id,
            WireMessage(MsgType.profileUpdate,
                {'id': _me.id, 'name': _me.name}),
          );
        }
      }
    }
  }

  // --- Inbound --------------------------------------------------------------

  void _onControl(InboundMessage inbound) {
    switch (inbound.message.type) {
      case MsgType.workspaceInvite:
        _onInvite(inbound);
      case MsgType.workspaceInviteResponse:
        _onInviteResponse(inbound);
      case MsgType.workspaceSync:
        _onSync(inbound);
      case MsgType.workspaceLeave:
        _onLeave(inbound);
      case MsgType.workspaceFolders:
        _onFolders(inbound);
      case MsgType.workspaceNotes:
        _onNotes(inbound);
      case MsgType.workspaceTasks:
        _onTasks(inbound);
      case MsgType.profileUpdate:
        _onProfile(inbound);
    }
  }

  void _onNotes(InboundMessage inbound) {
    final wsId = inbound.message.str('workspaceId');
    if (wsId == null || workspaceById(wsId) == null) return;
    final raw = inbound.message['notes'];
    if (raw is! List) return;
    final incoming = raw.map((e) => Note.fromJson(e as Map)).toList();
    _notes.removeWhere((n) => n.workspaceId == wsId);
    _notes.addAll(incoming);
    _db.replaceNotes(wsId, incoming);
    notifyListeners();
  }

  void _onTasks(InboundMessage inbound) {
    final wsId = inbound.message.str('workspaceId');
    if (wsId == null || workspaceById(wsId) == null) return;
    final raw = inbound.message['tasks'];
    if (raw is! List) return;
    final incoming = raw.map((e) => TaskItem.fromJson(e as Map)).toList();
    _tasks.removeWhere((t) => t.workspaceId == wsId);
    _tasks.addAll(incoming);
    _db.replaceTasks(wsId, incoming);
    notifyListeners();
  }

  void _broadcastNotes(String workspaceId) {
    final ws = workspaceById(workspaceId);
    if (ws == null) return;
    final payload = {
      'workspaceId': workspaceId,
      'notes': _notes
          .where((n) => n.workspaceId == workspaceId)
          .map((e) => e.toJson())
          .toList(),
    };
    for (final m in ws.others(_me.id)) {
      _network.sendControl(m.id, WireMessage(MsgType.workspaceNotes, payload));
    }
  }

  void _broadcastTasks(String workspaceId) {
    final ws = workspaceById(workspaceId);
    if (ws == null) return;
    final payload = {
      'workspaceId': workspaceId,
      'tasks': _tasks
          .where((t) => t.workspaceId == workspaceId)
          .map((e) => e.toJson())
          .toList(),
    };
    for (final m in ws.others(_me.id)) {
      _network.sendControl(m.id, WireMessage(MsgType.workspaceTasks, payload));
    }
  }

  void _onInvite(InboundMessage inbound) {
    final wsJson = inbound.message['workspace'];
    if (wsJson is! Map) return;
    final ws = Workspace.fromJson(wsJson);
    if (workspaceById(ws.id) != null) return;
    if (_pendingInvites.any((i) => i.workspace.id == ws.id)) return;
    _pendingInvites.add(WorkspaceInvite(
      workspace: ws,
      fromId: inbound.message.str('from') ?? inbound.peerId,
      fromName: inbound.message.str('fromName') ?? '',
    ));
    notifyListeners();
  }

  void _onInviteResponse(InboundMessage inbound) {
    final wsId = inbound.message.str('workspaceId');
    final accepted = inbound.message['accepted'] == true;
    if (wsId == null || !accepted) return;
    final idx = _workspaces.indexWhere((w) => w.id == wsId);
    if (idx < 0) return;
    final ws = _workspaces[idx];
    if (!ws.isOwner(_me.id)) return;
    final memberJson = inbound.message['member'];
    if (memberJson is! Map) return;
    final member = WorkspaceMember.fromJson(memberJson);
    if (ws.members.any((m) => m.id == member.id)) return;
    final updated = ws.copyWith(members: [...ws.members, member]);
    _workspaces[idx] = updated;
    _db.upsertWorkspace(updated);
    notifyListeners();
    _broadcastSync(updated);
    // Share the current folder tree, notes and tasks with the newcomer.
    _network.sendControl(
      member.id,
      WireMessage(MsgType.workspaceFolders, {
        'workspaceId': updated.id,
        'folders': _folders
            .where((f) => f.workspaceId == updated.id)
            .map((e) => e.toJson())
            .toList(),
      }),
    );
    _network.sendControl(
      member.id,
      WireMessage(MsgType.workspaceNotes, {
        'workspaceId': updated.id,
        'notes': _notes
            .where((n) => n.workspaceId == updated.id)
            .map((e) => e.toJson())
            .toList(),
      }),
    );
    _network.sendControl(
      member.id,
      WireMessage(MsgType.workspaceTasks, {
        'workspaceId': updated.id,
        'tasks': _tasks
            .where((t) => t.workspaceId == updated.id)
            .map((e) => e.toJson())
            .toList(),
      }),
    );
  }

  void _onSync(InboundMessage inbound) {
    final wsJson = inbound.message['workspace'];
    if (wsJson is! Map) return;
    final incoming = Workspace.fromJson(wsJson);
    final idx = _workspaces.indexWhere((w) => w.id == incoming.id);
    if (idx < 0) {
      if (incoming.members.any((m) => m.id == _me.id)) {
        _workspaces.add(incoming);
        _db.upsertWorkspace(incoming);
        notifyListeners();
      }
      return;
    }
    _workspaces[idx] = incoming;
    _db.upsertWorkspace(incoming);
    notifyListeners();
  }

  void _onLeave(InboundMessage inbound) {
    final wsId = inbound.message.str('workspaceId');
    if (wsId == null) return;
    final idx = _workspaces.indexWhere((w) => w.id == wsId);
    if (idx < 0) return;
    final ws = _workspaces[idx];

    if (inbound.message['ownerLeft'] == true) {
      _removeWorkspaceLocal(wsId);
      notifyListeners();
      return;
    }

    final memberId = inbound.message.str('memberId');
    if (memberId == null) return;
    final updated = ws.copyWith(
      members: ws.members.where((m) => m.id != memberId).toList(),
    );
    _workspaces[idx] = updated;
    _db.upsertWorkspace(updated);
    notifyListeners();
    if (ws.isOwner(_me.id)) _broadcastSync(updated);
  }

  void _onFolders(InboundMessage inbound) {
    final wsId = inbound.message.str('workspaceId');
    if (wsId == null || workspaceById(wsId) == null) return;
    final raw = inbound.message['folders'];
    if (raw is! List) return;
    final incoming =
        raw.map((e) => Folder.fromJson(e as Map)).toList();
    _folders.removeWhere((f) => f.workspaceId == wsId);
    _folders.addAll(incoming);
    _db.replaceFolders(wsId, incoming);
    notifyListeners();
  }

  void _onProfile(InboundMessage inbound) {
    final id = inbound.message.str('id') ?? inbound.peerId;
    final name = inbound.message.str('name');
    if (name == null || name.isEmpty) return;
    var changed = false;
    for (var i = 0; i < _workspaces.length; i++) {
      final ws = _workspaces[i];
      if (!ws.members.any((m) => m.id == id && m.name != name)) continue;
      final members = ws.members
          .map((m) => m.id == id
              ? WorkspaceMember(id: m.id, name: name, platform: m.platform)
              : m)
          .toList();
      final updated = ws.copyWith(members: members);
      _workspaces[i] = updated;
      _db.upsertWorkspace(updated);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  // --- Helpers --------------------------------------------------------------

  void _removeWorkspaceLocal(String id) {
    _workspaces.removeWhere((w) => w.id == id);
    _folders.removeWhere((f) => f.workspaceId == id);
    _files.removeWhere((f) => f.workspaceId == id);
    _notes.removeWhere((n) => n.workspaceId == id);
    _tasks.removeWhere((t) => t.workspaceId == id);
    _db.deleteWorkspace(id);
  }

  void _broadcastSync(Workspace ws) {
    for (final m in ws.others(_me.id)) {
      _network.sendControl(
        m.id,
        WireMessage(MsgType.workspaceSync, {'workspace': ws.toJson()}),
      );
    }
  }

  void _broadcastFolders(String workspaceId) {
    final ws = workspaceById(workspaceId);
    if (ws == null) return;
    final payload = {
      'workspaceId': workspaceId,
      'folders': _folders
          .where((f) => f.workspaceId == workspaceId)
          .map((e) => e.toJson())
          .toList(),
    };
    for (final m in ws.others(_me.id)) {
      _network.sendControl(
        m.id,
        WireMessage(MsgType.workspaceFolders, payload),
      );
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
