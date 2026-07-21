/// A folder inside a workspace. Folders can nest (parentId points to another
/// folder in the same workspace; null means the workspace root).
class Folder {
  const Folder({
    required this.id,
    required this.workspaceId,
    required this.parentId,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final String? parentId;
  final String name;
  final int createdAt; // epoch millis

  Folder copyWith({String? name, String? parentId}) => Folder(
        id: id,
        workspaceId: workspaceId,
        parentId: parentId ?? this.parentId,
        name: name ?? this.name,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspaceId': workspaceId,
        'parentId': parentId,
        'name': name,
        'createdAt': createdAt,
      };

  factory Folder.fromJson(Map<dynamic, dynamic> m) => Folder(
        id: m['id'] as String,
        workspaceId: (m['workspaceId'] as String?) ?? '',
        parentId: m['parentId'] as String?,
        name: (m['name'] as String?) ?? '',
        createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
      );
}
