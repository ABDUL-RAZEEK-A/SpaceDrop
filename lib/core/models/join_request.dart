class JoinRequest {
  final String requestId;
  final String lobbyId;
  final String deviceId;
  final String deviceName;
  final String status; // PENDING, APPROVED, REJECTED
  final int requestedAt;

  JoinRequest({
    required this.requestId,
    required this.lobbyId,
    required this.deviceId,
    required this.deviceName,
    required this.status,
    required this.requestedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'lobbyId': lobbyId,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'status': status,
      'requestedAt': requestedAt,
    };
  }

  factory JoinRequest.fromMap(Map<String, dynamic> map) {
    return JoinRequest(
      requestId: map['requestId'] ?? '',
      lobbyId: map['lobbyId'] ?? '',
      deviceId: map['deviceId'] ?? '',
      deviceName: map['deviceName'] ?? '',
      status: map['status'] ?? '',
      requestedAt: map['requestedAt']?.toInt() ?? 0,
    );
  }
}
