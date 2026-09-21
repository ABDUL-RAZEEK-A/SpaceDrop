import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import '../../../../features/lobby/domain/models/lobby.dart';
import '../../../../features/participants/domain/models/participant.dart';
import '../../../../features/file_transfer/domain/models/shared_file.dart';
import '../../../../core/models/join_request.dart';
import '../../../../features/discovery/domain/discovery_service.dart';
import '../../../../core/network/tcp_server.dart';
import 'package:crypto/crypto.dart';
import 'active_lobbies_provider.dart';

enum FileSortType { name, size, category }

class ClientEndpoint {
  final InternetAddress address;
  final int port;
  ClientEndpoint(this.address, this.port);
}

final hostProvider = StateNotifierProvider.family<HostNotifier, HostState, String>((ref, lobbyId) {
  return HostNotifier(lobbyId, ref);
});

class HostState {
  final Lobby? currentLobby;
  final List<Participant> participants;
  final List<JoinRequest> pendingRequests;
  final List<JoinRequest> coHostRequests;
  final List<SharedFile> sharedFiles;
  final bool isHosting;
  final String searchQuery;
  final FileSortType sortType;

  HostState({
    this.currentLobby,
    this.participants = const [],
    this.pendingRequests = const [],
    this.coHostRequests = const [],
    this.sharedFiles = const [],
    this.isHosting = false,
    this.searchQuery = '',
    this.sortType = FileSortType.category,
  });

  HostState copyWith({
    Lobby? currentLobby,
    List<Participant>? participants,
    List<JoinRequest>? pendingRequests,
    List<JoinRequest>? coHostRequests,
    List<SharedFile>? sharedFiles,
    bool? isHosting,
    String? searchQuery,
    FileSortType? sortType,
  }) {
    return HostState(
      currentLobby: currentLobby ?? this.currentLobby,
      participants: participants ?? this.participants,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      coHostRequests: coHostRequests ?? this.coHostRequests,
      sharedFiles: sharedFiles ?? this.sharedFiles,
      isHosting: isHosting ?? this.isHosting,
      searchQuery: searchQuery ?? this.searchQuery,
      sortType: sortType ?? this.sortType,
    );
  }

  List<SharedFile> get filteredAndSortedFiles {
    var files = sharedFiles.where((f) {
      if (searchQuery.isEmpty) return true;
      return f.fileName.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    files.sort((a, b) {
      switch (sortType) {
        case FileSortType.name:
          return a.fileName.compareTo(b.fileName);
        case FileSortType.size:
          return b.fileSize.compareTo(a.fileSize);
        case FileSortType.category:
          return a.fileType.compareTo(b.fileType);
      }
    });

    return files;
  }
}

class HostNotifier extends StateNotifier<HostState> {
  final String lobbyId;
  final Ref ref;
  HostNotifier(this.lobbyId, this.ref) : super(HostState());

  final DiscoveryService _discoveryService = DiscoveryService();
  final TcpServer _quicServer = TcpServer();
  final _uuid = const Uuid();
  
  final Map<String, ClientEndpoint> _deviceEndpoints = {};

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSortType(FileSortType sortType) {
    state = state.copyWith(sortType: sortType);
  }

  Future<void> createLobby(String lobbyName, String hostName, String lobbyType, bool pinEnabled, String? pin, int maxParticipants, bool requireManualApproval) async {
    try {
      await _quicServer.startServers();

      final hostDeviceId = _uuid.v4();

      final lobby = Lobby(
        lobbyId: lobbyId,
        lobbyName: lobbyName,
        hostDeviceId: hostDeviceId,
        hostDeviceName: hostName,
        hostIp: await _getLocalIpAddress(),
        port: _quicServer.port,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        status: 'ACTIVE',
        maxParticipants: maxParticipants,
        lobbyType: lobbyType,
        pinEnabled: pinEnabled,
        pin: pinEnabled ? pin : null,
        requireManualApproval: requireManualApproval,
      );

      await _discoveryService.advertiseLobby(lobby);

      _quicServer.onMessageReceived = _handleClientMessage;
      _quicServer.onFileRequested = _handleFileRequested;
      _quicServer.onTokenValidated = _validateSessionToken;
      _quicServer.onUploadRequested = _validateUploadToken;
      _quicServer.onFileUploaded = addSharedFile;

      state = state.copyWith(currentLobby: lobby, isHosting: true);
    } catch (e) {
      debugPrint('Failed to create lobby: $e');
    }
  }

  void updateMaxParticipants(int newMax) {
    if (state.currentLobby != null) {
      final updatedLobby = Lobby(
        lobbyId: state.currentLobby!.lobbyId,
        lobbyName: state.currentLobby!.lobbyName,
        hostDeviceId: state.currentLobby!.hostDeviceId,
        hostDeviceName: state.currentLobby!.hostDeviceName,
        hostIp: state.currentLobby!.hostIp,
        port: state.currentLobby!.port,
        createdAt: state.currentLobby!.createdAt,
        status: state.currentLobby!.status,
        maxParticipants: newMax,
        currentParticipants: state.currentLobby!.currentParticipants,
        lobbyType: state.currentLobby!.lobbyType,
        pinEnabled: state.currentLobby!.pinEnabled,
        pin: state.currentLobby!.pin,
        requireManualApproval: state.currentLobby!.requireManualApproval,
      );
      state = state.copyWith(currentLobby: updatedLobby);
      _discoveryService.advertiseLobby(updatedLobby);
    }
  }

  File? _handleFileRequested(String? fileId) {
    if (fileId == null) return null;
    try {
      final fileInfo = state.sharedFiles.firstWhere((f) => f.fileId == fileId);
      return File(fileInfo.filePath);
    } catch (_) {
      return null;
    }
  }

  bool _validateSessionToken(String? token) {
    if (token == null) return false;
    if (state.currentLobby?.isPaused == true) return false;
    return state.participants.any((p) => p.sessionToken == token);
  }

  bool _validateUploadToken(String? token) {
    if (token == null) return false;
    final participant = state.participants.firstWhere(
        (p) => p.sessionToken == token, 
        orElse: () => Participant(participantId: '', deviceId: '', deviceName: '', lobbyId: '', status: '', joinedAt: 0, permission: 'VIEWER'));
    return participant.permission == 'CO_HOST' || participant.permission == 'HOST';
  }

  void _handleClientMessage(Map<String, dynamic> message, InternetAddress address, int port) {
    final command = message['command'];
    if (command == 'join_request') {
      final deviceId = message['deviceId'];

      if (state.currentLobby?.isPaused == true) {
        _quicServer.sendMessage(address, port, {'command': 'join_rejected', 'reason': 'Lobby is paused'});
        return;
      }

      if (state.currentLobby != null && state.participants.length >= state.currentLobby!.maxParticipants) {
        _quicServer.sendMessage(address, port, {'command': 'join_rejected', 'reason': 'Lobby is full'});
        return;
      }
      
      if (state.currentLobby?.pinEnabled == true) {
        final pin = message['pin'];
        if (pin != state.currentLobby?.pin) {
          _quicServer.sendMessage(address, port, {'command': 'join_rejected', 'reason': 'Invalid PIN'});
          return;
        }
      }

      _deviceEndpoints[deviceId] = ClientEndpoint(address, port);
      
      if (state.currentLobby?.requireManualApproval == false) {
        // Auto-approve
        final participant = Participant(
          participantId: _uuid.v4(),
          deviceId: deviceId,
          deviceName: message['deviceName'],
          lobbyId: state.currentLobby!.lobbyId,
          status: 'CONNECTED',
          joinedAt: DateTime.now().millisecondsSinceEpoch,
          permission: 'VIEWER',
          sessionToken: _uuid.v4(),
        );
        state = state.copyWith(
          participants: [...state.participants, participant],
        );
        _quicServer.sendMessage(address, port, {
          'command': 'join_approved',
          'participantId': participant.participantId,
          'sessionToken': participant.sessionToken,
        });
        state = state.copyWith(
          currentLobby: state.currentLobby?.copyWith(currentParticipants: state.participants.length),
        );
      } else {
        final request = JoinRequest(
          requestId: _uuid.v4(),
          lobbyId: state.currentLobby!.lobbyId,
          deviceId: deviceId,
          deviceName: message['deviceName'],
          status: 'PENDING',
          requestedAt: DateTime.now().millisecondsSinceEpoch,
        );
        state = state.copyWith(
          pendingRequests: [...state.pendingRequests, request],
        );
        _broadcastPendingRequests();
      }
    } else {
      // Co-host commands handling
      final participant = state.participants.firstWhere(
        (p) {
           final ep = _deviceEndpoints[p.deviceId];
           return ep?.address == address && ep?.port == port;
        },
        orElse: () => Participant(participantId: '', deviceId: '', deviceName: '', lobbyId: '', status: '', joinedAt: 0, permission: 'VIEWER')
      );

      if (command == 'request_cohost') {
        if (participant.participantId.isNotEmpty && participant.permission == 'VIEWER') {
          final request = JoinRequest(
            requestId: _uuid.v4(),
            lobbyId: state.currentLobby!.lobbyId,
            deviceId: participant.deviceId,
            deviceName: participant.deviceName,
            status: 'PENDING',
            requestedAt: DateTime.now().millisecondsSinceEpoch,
          );
          state = state.copyWith(coHostRequests: [...state.coHostRequests, request]);
        }
      } else if (participant.permission == 'CO_HOST') {
        if (command == 'remove_file') {
          final fileId = message['fileId'];
          _removeFileInternal(fileId);
        } else if (command == 'approve_request') {
          final requestId = message['requestId'];
          final request = state.pendingRequests.firstWhere((r) => r.requestId == requestId, orElse: () => JoinRequest(requestId: '', lobbyId: '', deviceId: '', deviceName: '', status: '', requestedAt: 0));
          if (request.requestId.isNotEmpty) approveRequest(request);
        } else if (command == 'reject_request') {
          final requestId = message['requestId'];
          final request = state.pendingRequests.firstWhere((r) => r.requestId == requestId, orElse: () => JoinRequest(requestId: '', lobbyId: '', deviceId: '', deviceName: '', status: '', requestedAt: 0));
          if (request.requestId.isNotEmpty) rejectRequest(request);
        } else if (command == 'pause_lobby') {
          if (state.currentLobby?.isPaused == false) {
             togglePauseLobby();
          }
        } else if (command == 'unpause_lobby') {
          if (state.currentLobby?.isPaused == true) {
             togglePauseLobby();
          }
        }
      }
    }
  }

  void approveRequest(JoinRequest request) {
    final updatedRequests = state.pendingRequests
        .where((r) => r.requestId != request.requestId)
        .toList();

    final endpoint = _deviceEndpoints[request.deviceId];

    final sessionToken = _uuid.v4();

    final participant = Participant(
      participantId: _uuid.v4(),
      deviceId: request.deviceId,
      deviceName: request.deviceName,
      lobbyId: state.currentLobby!.lobbyId,
      status: 'APPROVED',
      joinedAt: DateTime.now().millisecondsSinceEpoch,
      permission: 'VIEWER',
      sessionToken: sessionToken,
    );

    state = state.copyWith(
      pendingRequests: updatedRequests,
      participants: [...state.participants, participant],
    );
    _broadcastPendingRequests();

    if (endpoint != null) {
      _quicServer.sendMessage(endpoint.address, endpoint.port, {
        'command': 'join_approved',
        'httpPort': _quicServer.port,
        'sessionToken': sessionToken,
      });
      _sendFileListToClient(endpoint);
    }
  }

  void rejectRequest(JoinRequest request) {
    final updatedRequests = state.pendingRequests
        .where((r) => r.requestId != request.requestId)
        .toList();
    state = state.copyWith(pendingRequests: updatedRequests);
    _broadcastPendingRequests();

    final endpoint = _deviceEndpoints[request.deviceId];
    if (endpoint != null) {
      _quicServer.sendMessage(endpoint.address, endpoint.port, {'command': 'join_rejected'});
    }
  }

  void promoteToCoHost(String deviceId) {
    final updatedParticipants = state.participants.map<Participant>((p) {
      if (p.deviceId == deviceId) {
        return p.copyWith(permission: 'CO_HOST');
      }
      return p;
    }).toList();
    state = state.copyWith(participants: updatedParticipants);

    final endpoint = _deviceEndpoints[deviceId];
    if (endpoint != null) {
      _quicServer.sendMessage(endpoint.address, endpoint.port, {'command': 'promote_cohost'});
      // Send them the current pending requests since they are now a co-host
      _sendPendingRequestsToClient(endpoint);
    }
  }

  void approveCoHostRequest(JoinRequest request) {
    final updatedRequests = state.coHostRequests
        .where((r) => r.requestId != request.requestId)
        .toList();
    state = state.copyWith(coHostRequests: updatedRequests);
    promoteToCoHost(request.deviceId);
  }

  void rejectCoHostRequest(JoinRequest request) {
    final updatedRequests = state.coHostRequests
        .where((r) => r.requestId != request.requestId)
        .toList();
    state = state.copyWith(coHostRequests: updatedRequests);
  }

  void togglePauseLobby() {
    if (state.currentLobby != null) {
      final updatedLobby = Lobby(
        lobbyId: state.currentLobby!.lobbyId,
        lobbyName: state.currentLobby!.lobbyName,
        hostDeviceId: state.currentLobby!.hostDeviceId,
        hostDeviceName: state.currentLobby!.hostDeviceName,
        hostIp: state.currentLobby!.hostIp,
        port: state.currentLobby!.port,
        createdAt: state.currentLobby!.createdAt,
        status: state.currentLobby!.status,
        maxParticipants: state.currentLobby!.maxParticipants,
        currentParticipants: state.currentLobby!.currentParticipants,
        lobbyType: state.currentLobby!.lobbyType,
        pinEnabled: state.currentLobby!.pinEnabled,
        pin: state.currentLobby!.pin,
        isPaused: !state.currentLobby!.isPaused,
      );
      state = state.copyWith(currentLobby: updatedLobby);
      _discoveryService.advertiseLobby(updatedLobby);
      _broadcastLobbyState(updatedLobby.isPaused);
    }
  }

  void _broadcastLobbyState(bool isPaused) {
    for (var device in state.participants) {
      final endpoint = _deviceEndpoints[device.deviceId];
      if (endpoint != null) {
        _quicServer.sendMessage(endpoint.address, endpoint.port, {
          'command': 'lobby_state_update',
          'isPaused': isPaused,
        });
      }
    }
  }

  void removeParticipant(String deviceId) {
    final updatedParticipants = state.participants.where((p) => p.deviceId != deviceId).toList();
    state = state.copyWith(participants: updatedParticipants);
    
    final endpoint = _deviceEndpoints[deviceId];
    if (endpoint != null) {
      _quicServer.sendMessage(endpoint.address, endpoint.port, {'command': 'join_rejected', 'reason': 'Kicked by host'});
      _deviceEndpoints.remove(deviceId);
    }
  }

  Future<void> addSharedFile(File file) async {
    try {
      final isDir = await FileSystemEntity.isDirectory(file.path);
      if (isDir) {
        print('Skipping directory: ${file.path}');
        return;
      }
      
      final digest = await sha256.bind(file.openRead()).first;
      final hash = digest.toString();

      final sharedFile = SharedFile(
        fileId: _uuid.v4(),
        fileName: p.basename(file.path),
        filePath: file.path,
        fileSize: await file.length(),
        fileType: 'application/octet-stream',
        checksum: hash,
        uploadedAt: DateTime.now().millisecondsSinceEpoch,
      );

      state = state.copyWith(sharedFiles: [...state.sharedFiles, sharedFile]);
      _broadcastFileList();
    } catch (e) {
      print('Error adding shared file: $e');
    }
  }

  void removeFile(String fileId) {
    _removeFileInternal(fileId);
  }

  void _removeFileInternal(String fileId) {
    final updatedFiles = state.sharedFiles.where((f) => f.fileId != fileId).toList();
    state = state.copyWith(sharedFiles: updatedFiles);
    _broadcastFileList();
  }

  void _sendFileListToClient(ClientEndpoint endpoint) {
    if (state.currentLobby == null) return;
    
    final fileData = state.sharedFiles.map((f) => {
      'fileId': f.fileId,
      'fileName': f.fileName,
      'fileSize': f.fileSize,
      'fileType': f.fileType,
      'checksum': f.checksum,
    }).toList();
    
    _quicServer.sendMessage(endpoint.address, endpoint.port, {
      'command': 'file_list_update',
      'files': fileData,
    });
  }

  void _broadcastFileList() {
    if (state.currentLobby == null) return;
    
    final fileData = state.sharedFiles.map((f) => {
      'fileId': f.fileId,
      'fileName': f.fileName,
      'fileSize': f.fileSize,
      'fileType': f.fileType,
      'checksum': f.checksum,
    }).toList();
    
    for (var device in state.participants) {
      final endpoint = _deviceEndpoints[device.deviceId];
      if (endpoint != null) {
        _quicServer.sendMessage(endpoint.address, endpoint.port, {
          'command': 'file_list_update',
          'files': fileData,
        });
      }
    }
  }

  void _broadcastPendingRequests() {
    final requestData = state.pendingRequests.map((r) => {
      'requestId': r.requestId,
      'deviceId': r.deviceId,
      'deviceName': r.deviceName,
    }).toList();

    for (var device in state.participants) {
      if (device.permission == 'CO_HOST') {
        final endpoint = _deviceEndpoints[device.deviceId];
        if (endpoint != null) {
          _sendPendingRequestsToClient(endpoint, requestData);
        }
      }
    }
  }

  void _sendPendingRequestsToClient(ClientEndpoint endpoint, [List<Map<String, dynamic>>? requestData]) {
    final data = requestData ?? state.pendingRequests.map((r) => {
      'requestId': r.requestId,
      'deviceId': r.deviceId,
      'deviceName': r.deviceName,
    }).toList();

    _quicServer.sendMessage(endpoint.address, endpoint.port, {
      'command': 'pending_requests_update',
      'requests': data,
    });
  }

  Future<void> closeLobby() async {
    await _discoveryService.stopAdvertising();
    _quicServer.stopServers();
    _deviceEndpoints.clear();
    ref.read(activeLobbiesProvider.notifier).removeLobby(lobbyId);
    state = HostState();
  }

  Future<String> _getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: true,
    );
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
          return addr.address;
        }
      }
    }
    return '127.0.0.1';
  }
}

