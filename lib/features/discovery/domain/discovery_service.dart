import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:nsd/nsd.dart';
import '../../lobby/domain/models/lobby.dart';

class DiscoveryService {
  final String _serviceType = '_spacedrop._tcp';
  Registration? _registration;
  Discovery? _discovery;

  final _lobbiesController = StreamController<List<Lobby>>.broadcast();
  Stream<List<Lobby>> get lobbiesStream => _lobbiesController.stream;

  final Map<String, Lobby> _discoveredLobbies = {};

  // Host: Advertise the lobby
  Future<void> advertiseLobby(Lobby lobby) async {
    try {
      if (_registration != null) {
        await stopAdvertising();
      }

      final txt = {
        'lobbyId': utf8.encode(lobby.lobbyId),
        'hostDeviceId': utf8.encode(lobby.hostDeviceId),
        'hostDeviceName': utf8.encode(lobby.hostDeviceName),
        'maxParticipants': utf8.encode(lobby.maxParticipants.toString()),
        'currentParticipants': utf8.encode(lobby.currentParticipants.toString()),
        'lobbyType': utf8.encode(lobby.lobbyType),
        'pinEnabled': utf8.encode(lobby.pinEnabled.toString()),
      };

      _registration = await register(
        Service(
          name: lobby.lobbyName,
          type: _serviceType,
          port: lobby.port,
          txt: txt,
        ),
      );
      debugPrint('Lobby advertised successfully: ${lobby.lobbyName}');
    } catch (e) {
      debugPrint('Error advertising lobby: $e');
      rethrow;
    }
  }

  // Host: Stop advertising
  Future<void> stopAdvertising() async {
    if (_registration != null) {
      await unregister(_registration!);
      _registration = null;
    }
  }

  // Client: Start searching for lobbies
  Future<void> startScanning() async {
    try {
      if (_discovery != null) {
        await stopScanning();
      }

      _discoveredLobbies.clear();
      _lobbiesController.add([]);

      _discovery = await startDiscovery(_serviceType);

      _discovery!.addListener(() {
        final services = _discovery!.services;
        _discoveredLobbies.clear();

        for (var service in services) {
          if (service.name != null &&
              service.host != null &&
              service.port != null) {
            try {
              final txt = service.txt ?? {};
              String getTxtValue(String key) {
                final bytes = txt[key];
                return bytes != null ? utf8.decode(bytes) : '';
              }

              final lobby = Lobby(
                lobbyId: getTxtValue('lobbyId'),
                lobbyName: service.name!,
                hostDeviceId: getTxtValue('hostDeviceId'),
                hostDeviceName: getTxtValue('hostDeviceName'),
                hostIp: service.host!,
                port: service.port!,
                createdAt: DateTime.now().millisecondsSinceEpoch,
                status: 'ACTIVE',
                maxParticipants:
                    int.tryParse(getTxtValue('maxParticipants')) ?? 10,
                currentParticipants:
                    int.tryParse(getTxtValue('currentParticipants')) ?? 0,
                lobbyType: getTxtValue('lobbyType').isNotEmpty ? getTxtValue('lobbyType') : 'Open',
                pinEnabled: getTxtValue('pinEnabled') == 'true',
              );

              _discoveredLobbies[lobby.lobbyId] = lobby;
            } catch (e) {
              debugPrint('Error parsing service data: $e');
            }
          }
        }

        _lobbiesController.add(_discoveredLobbies.values.toList());
      });
    } catch (e) {
      debugPrint('Error starting discovery: $e');
      rethrow;
    }
  }

  // Client: Stop searching for lobbies
  Future<void> stopScanning() async {
    if (_discovery != null) {
      await stopDiscovery(_discovery!);
      _discovery = null;
    }
  }
}
