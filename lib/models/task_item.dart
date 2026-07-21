enum TaskStatus { todo, doing, done }

/// A to-do item stored inside a workspace folder. Has a kanban [status], an
/// optional [category] label and a longer [description].
class TaskItem {
  const TaskItem({
    required this.id,
    required this.workspaceId,
    required this.folderId,
    required this.text,
    required this.status,
    required this.category,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final String? folderId;
  final String text;
  final TaskStatus status;
  final String category; // '' = uncategorized
  final String description;
  final int createdAt;

  bool get done => status == TaskStatus.done;

  TaskItem copyWith({
    String? text,
    TaskStatus? status,
    String? category,
    String? description,
  }) =>
      TaskItem(
        id: id,
        workspaceId: workspaceId,
        folderId: folderId,
        text: text ?? this.text,
        status: status ?? this.status,
        category: category ?? this.category,
        description: description ?? this.description,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspaceId': workspaceId,
        'folderId': folderId,
        'text': text,
        'status': status.index,
        'category': category,
        'description': description,
        'done': done, // kept for backward compatibility
        'createdAt': createdAt,
      };

  factory TaskItem.fromJson(Map<dynamic, dynamic> m) {
    final statusIndex = (m['status'] as num?)?.toInt();
    final status = statusIndex != null &&
            statusIndex >= 0 &&
            statusIndex < TaskStatus.values.length
        ? TaskStatus.values[statusIndex]
        : (m['done'] == true ? TaskStatus.done : TaskStatus.todo);
    return TaskItem(
      id: m['id'] as String,
      workspaceId: (m['workspaceId'] as String?) ?? '',
      folderId: m['folderId'] as String?,
      text: (m['text'] as String?) ?? '',
      status: status,
      category: (m['category'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}
