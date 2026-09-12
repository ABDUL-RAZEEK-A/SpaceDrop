class TransferHistory {
  final String transferId;
  final String fileName;
  final int fileSize;
  final String senderName;
  final String direction; // UPLOAD, DOWNLOAD
  final String status; // PENDING, IN_PROGRESS, COMPLETED, FAILED, CANCELLED
  final int completedAt;
  final String? errorReason;

  TransferHistory({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.senderName,
    required this.direction,
    required this.status,
    required this.completedAt,
    this.errorReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'transferId': transferId,
      'fileName': fileName,
      'fileSize': fileSize,
      'senderName': senderName,
      'direction': direction,
      'status': status,
      'completedAt': completedAt,
      if (errorReason != null) 'errorReason': errorReason,
    };
  }

  factory TransferHistory.fromMap(Map<String, dynamic> map) {
    return TransferHistory(
      transferId: map['transferId'] ?? '',
      fileName: map['fileName'] ?? '',
      fileSize: map['fileSize']?.toInt() ?? 0,
      senderName: map['senderName'] ?? '',
      direction: map['direction'] ?? 'DOWNLOAD',
      status: map['status'] ?? 'PENDING',
      completedAt: map['completedAt']?.toInt() ?? 0,
      errorReason: map['errorReason'],
    );
  }
}
