class Lobby {
  final String lobbyId;
  final String lobbyName;
  final String hostDeviceId;
  final String hostDeviceName;
  final String hostIp;
  final int port;
  final int createdAt;
  final String status;
  final int maxParticipants;
  final int currentParticipants;
  final String lobbyType; // 'Open' or 'Private'
  final bool pinEnabled;
  final String? pin;

  Lobby({
    required this.lobbyId,
    required this.lobbyName,
    required this.hostDeviceId,
    required this.hostDeviceName,
    required this.hostIp,
    required this.port,
    required this.createdAt,
    required this.status,
    required this.maxParticipants,
    this.currentParticipants = 0,
    this.lobbyType = 'Open',
    this.pinEnabled = false,
    this.pin,
  });

  Map<String, dynamic> toMap() {
    return {
      'lobbyId': lobbyId,
      'lobbyName': lobbyName,
      'hostDeviceId': hostDeviceId,
      'hostDeviceName': hostDeviceName,
      'hostIp': hostIp,
      'port': port,
      'createdAt': createdAt,
      'status': status,
      'maxParticipants': maxParticipants,
      'currentParticipants': currentParticipants,
      'lobbyType': lobbyType,
      'pinEnabled': pinEnabled,
      if (pin != null) 'pin': pin,
    };
  }

  factory Lobby.fromMap(Map<String, dynamic> map) {
    return Lobby(
      lobbyId: map['lobbyId'] ?? '',
      lobbyName: map['lobbyName'] ?? '',
      hostDeviceId: map['hostDeviceId'] ?? '',
      hostDeviceName: map['hostDeviceName'] ?? '',
      hostIp: map['hostIp'] ?? '',
      port: map['port']?.toInt() ?? 0,
      createdAt: map['createdAt']?.toInt() ?? 0,
      status: map['status'] ?? '',
      maxParticipants: map['maxParticipants']?.toInt() ?? 0,
      currentParticipants: map['currentParticipants']?.toInt() ?? 0,
      lobbyType: map['lobbyType'] ?? 'Open',
      pinEnabled: map['pinEnabled'] ?? false,
      pin: map['pin'],
    );
  }
}
