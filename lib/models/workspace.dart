/// A device that belongs to a workspace.
class WorkspaceMember {
  const WorkspaceMember({
    required this.id,
    required this.name,
    required this.platform,
  });

  final String id;
  final String name;
  final String platform;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'platform': platform};

  factory WorkspaceMember.fromJson(Map<dynamic, dynamic> m) => WorkspaceMember(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        platform: (m['platform'] as String?) ?? 'unknown',
      );

  @override
  bool operator ==(Object other) =>
      other is WorkspaceMember && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A shared space: a named group of devices that can exchange files.
///
/// One device is the owner (it created the space and manages membership); the
/// others are members that accepted an invitation.
class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.members,
  });

  final String id;
  final String name;
  final String ownerId;
  final List<WorkspaceMember> members;

  bool isOwner(String myId) => ownerId == myId;

  /// Members other than [myId].
  List<WorkspaceMember> others(String myId) =>
      members.where((m) => m.id != myId).toList();

  Workspace copyWith({String? name, List<WorkspaceMember>? members}) =>
      Workspace(
        id: id,
        name: name ?? this.name,
        ownerId: ownerId,
        members: members ?? this.members,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'members': members.map((e) => e.toJson()).toList(),
      };

  factory Workspace.fromJson(Map<dynamic, dynamic> m) => Workspace(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        ownerId: (m['ownerId'] as String?) ?? '',
        members: ((m['members'] as List?) ?? const [])
            .map((e) => WorkspaceMember.fromJson(e as Map))
            .toList(),
      );
}

/// A pending invitation to join a workspace, received from another device.
class WorkspaceInvite {
  const WorkspaceInvite({
    required this.workspace,
    required this.fromId,
    required this.fromName,
  });

  final Workspace workspace;
  final String fromId;
  final String fromName;
}
