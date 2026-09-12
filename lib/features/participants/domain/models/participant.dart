class Participant {
  final String participantId;
  final String deviceId;
  final String deviceName;
  final String lobbyId;
  final String status; // PENDING, APPROVED, REJECTED, REMOVED, LEFT
  final int joinedAt;
  final String permission;
  final String? sessionToken;

  Participant({
    required this.participantId,
    required this.deviceId,
    required this.deviceName,
    required this.lobbyId,
    required this.status,
    required this.joinedAt,
    required this.permission,
    this.sessionToken,
  });

  Participant copyWith({
    String? participantId,
    String? deviceId,
    String? deviceName,
    String? lobbyId,
    String? status,
    int? joinedAt,
    String? permission,
    String? sessionToken,
  }) {
    return Participant(
      participantId: participantId ?? this.participantId,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      lobbyId: lobbyId ?? this.lobbyId,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      permission: permission ?? this.permission,
      sessionToken: sessionToken ?? this.sessionToken,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participantId': participantId,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'lobbyId': lobbyId,
      'status': status,
      'joinedAt': joinedAt,
      'permission': permission,
      if (sessionToken != null) 'sessionToken': sessionToken,
    };
  }

  factory Participant.fromMap(Map<String, dynamic> map) {
    return Participant(
      participantId: map['participantId'] ?? '',
      deviceId: map['deviceId'] ?? '',
      deviceName: map['deviceName'] ?? '',
      lobbyId: map['lobbyId'] ?? '',
      status: map['status'] ?? 'PENDING',
      joinedAt: map['joinedAt']?.toInt() ?? 0,
      permission: map['permission'] ?? 'VIEWER',
      sessionToken: map['sessionToken'],
    );
  }
}
