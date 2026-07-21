/// A completed file, persisted so the workspace's contents survive restarts.
class FileRecord {
  const FileRecord({
    required this.id,
    required this.workspaceId,
    required this.folderId,
    required this.name,
    required this.size,
    required this.path,
    required this.sha256,
    required this.incoming,
    required this.peerName,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final String? folderId; // null = workspace root
  final String name;
  final int size;
  final String path;
  final String? sha256;
  final bool incoming;
  final String peerName;
  final int createdAt; // epoch millis

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspaceId': workspaceId,
        'folderId': folderId,
        'name': name,
        'size': size,
        'path': path,
        'sha256': sha256,
        'incoming': incoming,
        'peerName': peerName,
        'createdAt': createdAt,
      };

  factory FileRecord.fromJson(Map<dynamic, dynamic> m) => FileRecord(
        id: m['id'] as String,
        workspaceId: (m['workspaceId'] as String?) ?? '',
        folderId: m['folderId'] as String?,
        name: (m['name'] as String?) ?? '',
        size: (m['size'] as num?)?.toInt() ?? 0,
        path: (m['path'] as String?) ?? '',
        sha256: m['sha256'] as String?,
        incoming: m['incoming'] == true,
        peerName: (m['peerName'] as String?) ?? '',
        createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
      );
}
