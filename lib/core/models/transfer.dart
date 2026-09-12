class Transfer {
  final String transferId;
  final String fileId;
  final String deviceId;
  final String status; // PENDING, IN_PROGRESS, COMPLETED, FAILED
  final double progress;
  final int bytesTransferred;
  final int startedAt;
  final int completedAt;

  Transfer({
    required this.transferId,
    required this.fileId,
    required this.deviceId,
    required this.status,
    required this.progress,
    required this.bytesTransferred,
    required this.startedAt,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'transferId': transferId,
      'fileId': fileId,
      'deviceId': deviceId,
      'status': status,
      'progress': progress,
      'bytesTransferred': bytesTransferred,
      'startedAt': startedAt,
      'completedAt': completedAt,
    };
  }

  factory Transfer.fromMap(Map<String, dynamic> map) {
    return Transfer(
      transferId: map['transferId'] ?? '',
      fileId: map['fileId'] ?? '',
      deviceId: map['deviceId'] ?? '',
      status: map['status'] ?? '',
      progress: map['progress']?.toDouble() ?? 0.0,
      bytesTransferred: map['bytesTransferred']?.toInt() ?? 0,
      startedAt: map['startedAt']?.toInt() ?? 0,
      completedAt: map['completedAt']?.toInt() ?? 0,
    );
  }
}
