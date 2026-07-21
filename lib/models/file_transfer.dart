enum TransferDirection { incoming, outgoing }

enum TransferStatus { offered, transferring, completed, failed, rejected }

/// State of a single file transfer (in either direction).
class FileTransfer {
  FileTransfer({
    required this.id,
    required this.workspaceId,
    required this.peerId,
    required this.peerName,
    required this.fileName,
    required this.size,
    required this.direction,
    this.status = TransferStatus.transferring,
  });

  final String id;
  final String workspaceId;
  final String peerId;
  final String peerName;
  final String fileName;
  final int size;
  final TransferDirection direction;

  TransferStatus status;
  int transferred = 0;
  String? savePath;
  String? error;

  bool get isIncoming => direction == TransferDirection.incoming;

  double get progress =>
      size <= 0 ? 0 : (transferred / size).clamp(0.0, 1.0);

  bool get isActive =>
      status == TransferStatus.offered || status == TransferStatus.transferring;

  bool get isDone =>
      status == TransferStatus.completed ||
      status == TransferStatus.failed ||
      status == TransferStatus.rejected;
}
