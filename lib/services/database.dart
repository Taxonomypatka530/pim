import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/file_record.dart';
import '../models/folder.dart';
import '../models/note.dart';
import '../models/task_item.dart';
import '../models/workspace.dart';

/// The app's own local database. Workspaces, folders and received/sent files
/// persist here so nothing is lost on restart. Cross-platform via
/// sqlite3_flutter_libs (bundles the native sqlite3 on Windows + Android).
class AppDatabase {
  AppDatabase._(this._db);
  final Database _db;

  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final pimDir = Directory('${dir.path}/PIM');
    if (!await pimDir.exists()) await pimDir.create(recursive: true);
    final db = sqlite3.open('${pimDir.path}/pim.db');

    db.execute('''
      CREATE TABLE IF NOT EXISTS workspaces (
        id TEXT PRIMARY KEY,
        name TEXT,
        owner_id TEXT,
        members TEXT
      )''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS folders (
        id TEXT PRIMARY KEY,
        workspace_id TEXT,
        parent_id TEXT,
        name TEXT,
        created_at INTEGER
      )''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS files (
        id TEXT PRIMARY KEY,
        workspace_id TEXT,
        folder_id TEXT,
        name TEXT,
        size INTEGER,
        path TEXT,
        sha256 TEXT,
        incoming INTEGER,
        peer_name TEXT,
        created_at INTEGER
      )''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        workspace_id TEXT,
        folder_id TEXT,
        text TEXT,
        created_at INTEGER,
        updated_at INTEGER
      )''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        workspace_id TEXT,
        folder_id TEXT,
        text TEXT,
        done INTEGER,
        status INTEGER DEFAULT 0,
        category TEXT DEFAULT '',
        description TEXT DEFAULT '',
        created_at INTEGER
      )''');

    // Migrate older task tables that lack the new columns.
    for (final col in [
      'status INTEGER DEFAULT 0',
      "category TEXT DEFAULT ''",
      "description TEXT DEFAULT ''",
    ]) {
      try {
        db.execute('ALTER TABLE tasks ADD COLUMN $col');
      } catch (_) {}
    }
    try {
      db.execute(
          'UPDATE tasks SET status = 2 WHERE done = 1 AND (status IS NULL OR status = 0)');
    } catch (_) {}

    return AppDatabase._(db);
  }

  // --- Workspaces -----------------------------------------------------------

  List<Workspace> loadWorkspaces() {
    try {
      final rows = _db.select('SELECT * FROM workspaces');
      return rows.map((r) {
        final membersJson = (r['members'] as String?) ?? '[]';
        final members = (jsonDecode(membersJson) as List)
            .map((e) => WorkspaceMember.fromJson(e as Map))
            .toList();
        return Workspace(
          id: r['id'] as String,
          name: (r['name'] as String?) ?? '',
          ownerId: (r['owner_id'] as String?) ?? '',
          members: members,
        );
      }).toList();
    } catch (e) {
      debugPrint('loadWorkspaces failed: $e');
      return [];
    }
  }

  void upsertWorkspace(Workspace w) {
    _run(() => _db.execute(
          'INSERT OR REPLACE INTO workspaces (id, name, owner_id, members) '
          'VALUES (?, ?, ?, ?)',
          [
            w.id,
            w.name,
            w.ownerId,
            jsonEncode(w.members.map((e) => e.toJson()).toList()),
          ],
        ));
  }

  void deleteWorkspace(String id) {
    _run(() {
      _db.execute('DELETE FROM workspaces WHERE id = ?', [id]);
      _db.execute('DELETE FROM folders WHERE workspace_id = ?', [id]);
      _db.execute('DELETE FROM files WHERE workspace_id = ?', [id]);
      _db.execute('DELETE FROM notes WHERE workspace_id = ?', [id]);
      _db.execute('DELETE FROM tasks WHERE workspace_id = ?', [id]);
    });
  }

  // --- Folders --------------------------------------------------------------

  List<Folder> loadFolders() {
    try {
      final rows = _db.select('SELECT * FROM folders');
      return rows
          .map((r) => Folder(
                id: r['id'] as String,
                workspaceId: (r['workspace_id'] as String?) ?? '',
                parentId: r['parent_id'] as String?,
                name: (r['name'] as String?) ?? '',
                createdAt: (r['created_at'] as int?) ?? 0,
              ))
          .toList();
    } catch (e) {
      debugPrint('loadFolders failed: $e');
      return [];
    }
  }

  void upsertFolder(Folder f) {
    _run(() => _db.execute(
          'INSERT OR REPLACE INTO folders '
          '(id, workspace_id, parent_id, name, created_at) VALUES (?, ?, ?, ?, ?)',
          [f.id, f.workspaceId, f.parentId, f.name, f.createdAt],
        ));
  }

  void deleteFolder(String id) {
    _run(() => _db.execute('DELETE FROM folders WHERE id = ?', [id]));
  }

  /// Replaces all folders for a workspace (used when applying a sync).
  void replaceFolders(String workspaceId, List<Folder> folders) {
    _run(() {
      _db.execute('DELETE FROM folders WHERE workspace_id = ?', [workspaceId]);
      for (final f in folders) {
        _db.execute(
          'INSERT OR REPLACE INTO folders '
          '(id, workspace_id, parent_id, name, created_at) VALUES (?, ?, ?, ?, ?)',
          [f.id, f.workspaceId, f.parentId, f.name, f.createdAt],
        );
      }
    });
  }

  // --- Files ----------------------------------------------------------------

  List<FileRecord> loadFiles() {
    try {
      final rows = _db.select('SELECT * FROM files ORDER BY created_at DESC');
      return rows
          .map((r) => FileRecord(
                id: r['id'] as String,
                workspaceId: (r['workspace_id'] as String?) ?? '',
                folderId: r['folder_id'] as String?,
                name: (r['name'] as String?) ?? '',
                size: (r['size'] as int?) ?? 0,
                path: (r['path'] as String?) ?? '',
                sha256: r['sha256'] as String?,
                incoming: ((r['incoming'] as int?) ?? 0) == 1,
                peerName: (r['peer_name'] as String?) ?? '',
                createdAt: (r['created_at'] as int?) ?? 0,
              ))
          .toList();
    } catch (e) {
      debugPrint('loadFiles failed: $e');
      return [];
    }
  }

  void upsertFile(FileRecord f) {
    _run(() => _db.execute(
          'INSERT OR REPLACE INTO files (id, workspace_id, folder_id, name, size, '
          'path, sha256, incoming, peer_name, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            f.id,
            f.workspaceId,
            f.folderId,
            f.name,
            f.size,
            f.path,
            f.sha256,
            f.incoming ? 1 : 0,
            f.peerName,
            f.createdAt,
          ],
        ));
  }

  void deleteFile(String id) {
    _run(() => _db.execute('DELETE FROM files WHERE id = ?', [id]));
  }

  // --- Notes ----------------------------------------------------------------

  List<Note> loadNotes() {
    try {
      final rows = _db.select('SELECT * FROM notes');
      return rows
          .map((r) => Note(
                id: r['id'] as String,
                workspaceId: (r['workspace_id'] as String?) ?? '',
                folderId: r['folder_id'] as String?,
                text: (r['text'] as String?) ?? '',
                createdAt: (r['created_at'] as int?) ?? 0,
                updatedAt: (r['updated_at'] as int?) ?? 0,
              ))
          .toList();
    } catch (e) {
      debugPrint('loadNotes failed: $e');
      return [];
    }
  }

  void upsertNote(Note n) {
    _run(() => _db.execute(
          'INSERT OR REPLACE INTO notes '
          '(id, workspace_id, folder_id, text, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [n.id, n.workspaceId, n.folderId, n.text, n.createdAt, n.updatedAt],
        ));
  }

  void deleteNote(String id) {
    _run(() => _db.execute('DELETE FROM notes WHERE id = ?', [id]));
  }

  void replaceNotes(String workspaceId, List<Note> notes) {
    _run(() {
      _db.execute('DELETE FROM notes WHERE workspace_id = ?', [workspaceId]);
      for (final n in notes) {
        _db.execute(
          'INSERT OR REPLACE INTO notes '
          '(id, workspace_id, folder_id, text, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [n.id, n.workspaceId, n.folderId, n.text, n.createdAt, n.updatedAt],
        );
      }
    });
  }

  // --- Tasks ----------------------------------------------------------------

  List<TaskItem> loadTasks() {
    try {
      final rows = _db.select('SELECT * FROM tasks');
      return rows.map(_taskFromRow).toList();
    } catch (e) {
      debugPrint('loadTasks failed: $e');
      return [];
    }
  }

  static TaskItem _taskFromRow(Row r) {
    final statusIdx = (r['status'] as int?) ??
        (((r['done'] as int?) ?? 0) == 1 ? 2 : 0);
    return TaskItem(
      id: r['id'] as String,
      workspaceId: (r['workspace_id'] as String?) ?? '',
      folderId: r['folder_id'] as String?,
      text: (r['text'] as String?) ?? '',
      status: statusIdx >= 0 && statusIdx < TaskStatus.values.length
          ? TaskStatus.values[statusIdx]
          : TaskStatus.todo,
      category: (r['category'] as String?) ?? '',
      description: (r['description'] as String?) ?? '',
      createdAt: (r['created_at'] as int?) ?? 0,
    );
  }

  static const String _taskCols =
      '(id, workspace_id, folder_id, text, done, status, category, '
      'description, created_at)';

  List<Object?> _taskValues(TaskItem t) => [
        t.id,
        t.workspaceId,
        t.folderId,
        t.text,
        t.done ? 1 : 0,
        t.status.index,
        t.category,
        t.description,
        t.createdAt,
      ];

  void replaceTasks(String workspaceId, List<TaskItem> tasks) {
    _run(() {
      _db.execute('DELETE FROM tasks WHERE workspace_id = ?', [workspaceId]);
      for (final t in tasks) {
        _db.execute(
          'INSERT OR REPLACE INTO tasks $_taskCols '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          _taskValues(t),
        );
      }
    });
  }

  void upsertTask(TaskItem t) {
    _run(() => _db.execute(
          'INSERT OR REPLACE INTO tasks $_taskCols '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          _taskValues(t),
        ));
  }

  void deleteTask(String id) {
    _run(() => _db.execute('DELETE FROM tasks WHERE id = ?', [id]));
  }

  void _run(void Function() op) {
    try {
      op();
    } catch (e) {
      debugPrint('db write failed: $e');
    }
  }

  void close() => _db.dispose();
}
