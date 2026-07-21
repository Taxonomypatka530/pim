enum ChatDirection { incoming, outgoing }

/// A single text message in a conversation with one peer.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.peerId,
    required this.direction,
    required this.text,
    required this.timestamp,
  });

  /// Unique message id (uuid). Shared by sender and receiver so acks can match.
  final String id;

  /// The id of the *other* device in this conversation.
  final String peerId;

  final ChatDirection direction;
  final String text;
  final DateTime timestamp;

  bool get isMine => direction == ChatDirection.outgoing;
}
