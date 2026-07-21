import 'dart:convert';
import 'dart:typed_data';

/// Message type identifiers exchanged between peers over a framed TCP stream.
///
/// Kept as plain strings (not an enum) so the protocol can evolve without
/// breaking older peers: an unknown type is simply ignored by the receiver.
class MsgType {
  MsgType._();

  /// Handshake sent immediately after a socket opens, so each side can map the
  /// raw socket to a logical device id.
  static const String hello = 'hello';

  /// A plain text chat message.
  static const String text = 'text';

  /// Acknowledgement of a received message (reserved for later phases).
  static const String ack = 'ack';

  // Workspace membership.
  static const String workspaceInvite = 'ws_invite';
  static const String workspaceInviteResponse = 'ws_invite_resp';
  static const String workspaceSync = 'ws_sync';
  static const String workspaceLeave = 'ws_leave';
  static const String workspaceFolders = 'ws_folders';
  static const String workspaceNotes = 'ws_notes';
  static const String workspaceTasks = 'ws_tasks';

  /// A device announcing its (possibly changed) display name.
  static const String profileUpdate = 'profile_update';

  // File transfer.
  static const String fileOffer = 'file_offer';
  static const String fileAccept = 'file_accept';
  static const String fileReject = 'file_reject';
  static const String fileComplete = 'file_complete';
  static const String fileCancel = 'file_cancel';
}

/// A single logical message on the wire.
///
/// The envelope is `{ "type": <string>, ...fields }` encoded as UTF-8 JSON.
/// Binary payloads (file chunks) will use a dedicated frame kind in a later
/// phase; for now every message is JSON.
class WireMessage {
  WireMessage(this.type, [Map<String, dynamic>? fields])
      : fields = fields ?? <String, dynamic>{};

  final String type;
  final Map<String, dynamic> fields;

  dynamic operator [](String key) => fields[key];

  String? str(String key) => fields[key] as String?;
  int? integer(String key) => fields[key] as int?;

  Uint8List encode() {
    final map = <String, dynamic>{'type': type, ...fields};
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  static WireMessage decode(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      return WireMessage('unknown');
    }
    final map = Map<String, dynamic>.from(decoded);
    final type = (map.remove('type') as String?) ?? 'unknown';
    return WireMessage(type, map);
  }

  @override
  String toString() => 'WireMessage($type, $fields)';
}
