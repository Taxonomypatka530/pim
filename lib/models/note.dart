/// A free-text note stored inside a workspace folder.
class Note {
  const Note({
    required this.id,
    required this.workspaceId,
    required this.folderId,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String? folderId;
  final String text;
  final int createdAt;
  final int updatedAt;

  /// First line, used as a title in the UI.
  String get title {
    final firstLine = text.trim().split('\n').first.trim();
    return firstLine.isEmpty ? 'Note' : firstLine;
  }

  Note copyWith({String? text, int? updatedAt}) => Note(
        id: id,
        workspaceId: workspaceId,
        folderId: folderId,
        text: text ?? this.text,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspaceId': workspaceId,
        'folderId': folderId,
        'text': text,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Note.fromJson(Map<dynamic, dynamic> m) => Note(
        id: m['id'] as String,
        workspaceId: (m['workspaceId'] as String?) ?? '',
        folderId: m['folderId'] as String?,
        text: (m['text'] as String?) ?? '',
        createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
      );
}
