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

enum FileSortType { name, size, category }

final hostProvider = StateNotifierProvider<HostNotifier, HostState>((ref) {
  return HostNotifier();
});

class HostState {
  final Lobby? currentLobby;
  final List<Participant> participants;
  final List<JoinRequest> pendingRequests;
  final List<SharedFile> sharedFiles;
  final bool isHosting;
  final String searchQuery;
  final FileSortType sortType;

  HostState({
    this.currentLobby,
    this.participants = const [],
    this.pendingRequests = const [],
    this.sharedFiles = const [],
    this.isHosting = false,
    this.searchQuery = '',
    this.sortType = FileSortType.category,
  });

  HostState copyWith({
    Lobby? currentLobby,
    List<Participant>? participants,
    List<JoinRequest>? pendingRequests,
    List<SharedFile>? sharedFiles,
    bool? isHosting,
    String? searchQuery,
    FileSortType? sortType,
  }) {
    return HostState(
      currentLobby: currentLobby ?? this.currentLobby,
      participants: participants ?? this.participants,
      pendingRequests: pendingRequests ?? this.pendingRequests,
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
  HostNotifier() : super(HostState());

  final DiscoveryService _discoveryService = DiscoveryService();
  final TcpServer _tcpServer = TcpServer();
  final _uuid = const Uuid();
  
  final Map<String, Socket> _deviceSockets = {};

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSortType(FileSortType sortType) {
    state = state.copyWith(sortType: sortType);
  }

  Future<void> createLobby(String lobbyName, String hostName, String lobbyType, bool pinEnabled, String? pin, int maxParticipants) async {
    try {
      await _tcpServer.startServers();

      final lobbyId = 'LND-${_uuid.v4().substring(0, 5).toUpperCase()}';
      final hostDeviceId = _uuid.v4();

      final lobby = Lobby(
        lobbyId: lobbyId,
        lobbyName: lobbyName,
        hostDeviceId: hostDeviceId,
        hostDeviceName: hostName,
        hostIp: await _getLocalIpAddress(),
        port: _tcpServer.tcpPort,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        status: 'ACTIVE',
        maxParticipants: maxParticipants,
        lobbyType: lobbyType,
        pinEnabled: pinEnabled,
        pin: pin,
      );

      await _discoveryService.advertiseLobby(lobby);

      _tcpServer.onMessageReceived = _handleClientMessage;
      _tcpServer.onFileRequested = _handleFileRequested;
      _tcpServer.onTokenValidated = _validateSessionToken;
      _tcpServer.onUploadRequested = _validateUploadToken;
      _tcpServer.onFileUploaded = addSharedFile;

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
    return state.participants.any((p) => p.sessionToken == token);
  }

  bool _validateUploadToken(String? token) {
    if (token == null) return false;
    final participant = state.participants.firstWhere(
        (p) => p.sessionToken == token, 
        orElse: () => Participant(participantId: '', deviceId: '', deviceName: '', lobbyId: '', status: '', joinedAt: 0, permission: 'VIEWER'));
    return participant.permission == 'CO_HOST' || participant.permission == 'HOST';
  }

  void _handleClientMessage(Socket client, Map<String, dynamic> message) {
    final command = message['command'];
    if (command == 'join_request') {
      final deviceId = message['deviceId'];

      if (state.currentLobby != null && state.participants.length >= state.currentLobby!.maxParticipants) {
        _tcpServer.sendMessage(client, {'command': 'join_rejected', 'reason': 'Lobby is full'});
        return;
      }
      
      if (state.currentLobby?.pinEnabled == true) {
        final pin = message['pin'];
        if (pin != state.currentLobby?.pin) {
          _tcpServer.sendMessage(client, {'command': 'join_rejected', 'reason': 'Invalid PIN'});
          return;
        }
      }

      _deviceSockets[deviceId] = client;
      
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
    } else {
      // Co-host commands handling
      final participant = state.participants.firstWhere(
        (p) => _deviceSockets[p.deviceId] == client, 
        orElse: () => Participant(participantId: '', deviceId: '', deviceName: '', lobbyId: '', status: '', joinedAt: 0, permission: 'VIEWER')
      );

      if (participant.permission == 'CO_HOST') {
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
        }
      }
    }
  }

  void approveRequest(JoinRequest request) {
    final updatedRequests = state.pendingRequests
        .where((r) => r.requestId != request.requestId)
        .toList();

    final socket = _deviceSockets[request.deviceId];

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

    if (socket != null) {
      _tcpServer.sendMessage(socket, {
        'command': 'join_approved',
        'httpPort': _tcpServer.httpPort,
        'sessionToken': sessionToken,
      });
      _sendFileListToClient(socket);
    }
  }

  void rejectRequest(JoinRequest request) {
    final updatedRequests = state.pendingRequests
        .where((r) => r.requestId != request.requestId)
        .toList();
    state = state.copyWith(pendingRequests: updatedRequests);
    _broadcastPendingRequests();

    final socket = _deviceSockets[request.deviceId];
    if (socket != null) {
      _tcpServer.sendMessage(socket, {'command': 'join_rejected'});
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

    final socket = _deviceSockets[deviceId];
    if (socket != null) {
      _tcpServer.sendMessage(socket, {'command': 'promote_cohost'});
      // Send them the current pending requests since they are now a co-host
      _sendPendingRequestsToClient(socket);
    }
  }

  void removeParticipant(String deviceId) {
    final updatedParticipants = state.participants.where((p) => p.deviceId != deviceId).toList();
    state = state.copyWith(participants: updatedParticipants);
    
    final socket = _deviceSockets[deviceId];
    if (socket != null) {
      _tcpServer.sendMessage(socket, {'command': 'join_rejected', 'reason': 'Kicked by host'});
      socket.destroy();
      _deviceSockets.remove(deviceId);
    }
  }

  Future<void> addSharedFile(File file) async {
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();

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
  }

  void removeFile(String fileId) {
    _removeFileInternal(fileId);
  }

  void _removeFileInternal(String fileId) {
    final updatedFiles = state.sharedFiles.where((f) => f.fileId != fileId).toList();
    state = state.copyWith(sharedFiles: updatedFiles);
    _broadcastFileList();
  }

  void _sendFileListToClient(Socket socket) {
    if (state.currentLobby == null) return;
    
    final fileData = state.sharedFiles.map((f) => {
      'fileId': f.fileId,
      'fileName': f.fileName,
      'fileSize': f.fileSize,
      'fileType': f.fileType,
      'checksum': f.checksum,
    }).toList();
    
    _tcpServer.sendMessage(socket, {
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
      final socket = _deviceSockets[device.deviceId];
      if (socket != null) {
        _tcpServer.sendMessage(socket, {
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
        final socket = _deviceSockets[device.deviceId];
        if (socket != null) {
          _sendPendingRequestsToClient(socket, requestData);
        }
      }
    }
  }

  void _sendPendingRequestsToClient(Socket socket, [List<Map<String, dynamic>>? requestData]) {
    final data = requestData ?? state.pendingRequests.map((r) => {
      'requestId': r.requestId,
      'deviceId': r.deviceId,
      'deviceName': r.deviceName,
    }).toList();

    _tcpServer.sendMessage(socket, {
      'command': 'pending_requests_update',
      'requests': data,
    });
  }

  Future<void> closeLobby() async {
    await _discoveryService.stopAdvertising();
    _tcpServer.stopServers();
    _deviceSockets.clear();
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

