import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../lobby/domain/models/lobby.dart';

class DiscoveryService {
  static const int _broadcastPort = 45454;
  
  RawDatagramSocket? _broadcastSocket;
  RawDatagramSocket? _listenSocket;
  Timer? _broadcastTimer;

  final _lobbiesController = StreamController<List<Lobby>>.broadcast();
  Stream<List<Lobby>> get lobbiesStream => _lobbiesController.stream;

  final Map<String, Lobby> _discoveredLobbies = {};
  final Map<String, Timer> _lobbyTimeouts = {};

  // Host: Advertise the lobby
  Future<void> advertiseLobby(Lobby lobby) async {
    try {
      await stopAdvertising();

      _broadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _broadcastSocket!.broadcastEnabled = true;

      final payload = jsonEncode({
        'lobbyId': lobby.lobbyId,
        'lobbyName': lobby.lobbyName,
        'hostDeviceId': lobby.hostDeviceId,
        'hostDeviceName': lobby.hostDeviceName,
        'maxParticipants': lobby.maxParticipants.toString(),
        'currentParticipants': lobby.currentParticipants.toString(),
        'lobbyType': lobby.lobbyType,
        'pinEnabled': lobby.pinEnabled.toString(),
        'port': lobby.port.toString(), // QUIC Port
      });
      final bytes = utf8.encode(payload);

      _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (_broadcastSocket != null) {
          try {
            _broadcastSocket!.send(bytes, InternetAddress('255.255.255.255'), _broadcastPort);
          } catch (e) {
            debugPrint('Error sending UDP broadcast: $e');
          }
        }
      });
      
      debugPrint('Lobby advertised successfully via UDP: ${lobby.lobbyName}');
    } catch (e) {
      debugPrint('Error advertising lobby: $e');
      rethrow;
    }
  }

  // Host: Stop advertising
  Future<void> stopAdvertising() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    
    _broadcastSocket?.close();
    _broadcastSocket = null;
  }

  // Client: Start searching for lobbies
  Future<void> startScanning() async {
    try {
      await stopScanning();

      _discoveredLobbies.clear();
      for (final timer in _lobbyTimeouts.values) {
        timer.cancel();
      }
      _lobbyTimeouts.clear();
      _lobbiesController.add([]);

      _listenSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _broadcastPort, reuseAddress: true, reusePort: true);

      _listenSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _listenSocket!.receive();
          if (datagram != null) {
            try {
              final payload = utf8.decode(datagram.data);
              final data = jsonDecode(payload) as Map<String, dynamic>;
              
              final lobbyId = data['lobbyId'] as String;
              
              final lobby = Lobby(
                lobbyId: lobbyId,
                lobbyName: data['lobbyName'] ?? 'Unknown',
                hostDeviceId: data['hostDeviceId'] ?? '',
                hostDeviceName: data['hostDeviceName'] ?? 'Unknown',
                hostIp: datagram.address.address, // Use the sender's IP address
                port: int.tryParse(data['port']?.toString() ?? '0') ?? 0,
                createdAt: DateTime.now().millisecondsSinceEpoch,
                status: 'ACTIVE',
                maxParticipants: int.tryParse(data['maxParticipants']?.toString() ?? '10') ?? 10,
                currentParticipants: int.tryParse(data['currentParticipants']?.toString() ?? '0') ?? 0,
                lobbyType: data['lobbyType'] ?? 'Open',
                pinEnabled: data['pinEnabled'] == 'true',
              );

              _discoveredLobbies[lobbyId] = lobby;
              _lobbiesController.add(_discoveredLobbies.values.toList());
              
              // Reset timeout for this lobby
              _lobbyTimeouts[lobbyId]?.cancel();
              _lobbyTimeouts[lobbyId] = Timer(const Duration(seconds: 10), () {
                _discoveredLobbies.remove(lobbyId);
                _lobbiesController.add(_discoveredLobbies.values.toList());
              });
              
            } catch (e) {
              // Ignore invalid packets
            }
          }
        }
      });
      debugPrint('Started UDP scanning on port $_broadcastPort');
    } catch (e) {
      debugPrint('Error starting UDP discovery: $e');
      rethrow;
    }
  }

  // Client: Stop searching for lobbies
  Future<void> stopScanning() async {
    for (final timer in _lobbyTimeouts.values) {
      timer.cancel();
    }
    _lobbyTimeouts.clear();
    
    _listenSocket?.close();
    _listenSocket = null;
  }
}
