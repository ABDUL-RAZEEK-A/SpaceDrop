import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import '../../../../features/lobby/domain/models/lobby.dart';
import '../../domain/discovery_service.dart';
import '../../../../core/network/tcp_client.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../features/history/domain/models/transfer_history.dart';
import 'package:crypto/crypto.dart';

final clientProvider = StateNotifierProvider<ClientNotifier, ClientState>((ref) {
  return ClientNotifier();
});

class ClientState {
  final List<Lobby> availableLobbies;
  final Lobby? connectedLobby;
  final bool isScanning;
  final String deviceId;
  final bool isApproved;
  final bool isCoHost;
  final int hostHttpPort;
  final List<Map<String, dynamic>> availableFiles;
  
  // Multi-download states
  final Set<String> selectedFileIds;
  final Map<String, double> downloadProgresses;
  final String? sessionToken;
  final List<Map<String, dynamic>> pendingRequests;
  final bool isPaused;
  final Set<String> pausedDownloads;

  ClientState({
    this.availableLobbies = const [],
    this.connectedLobby,
    this.isScanning = false,
    this.deviceId = '',
    this.isApproved = false,
    this.isCoHost = false,
    this.hostHttpPort = 0,
    this.availableFiles = const [],
    this.selectedFileIds = const {},
    this.downloadProgresses = const {},
    this.sessionToken,
    this.pendingRequests = const [],
    this.isPaused = false,
    this.pausedDownloads = const {},
  });

  ClientState copyWith({
    List<Lobby>? availableLobbies,
    Lobby? connectedLobby,
    bool? isScanning,
    String? deviceId,
    bool? isApproved,
    bool? isCoHost,
    int? hostHttpPort,
    List<Map<String, dynamic>>? availableFiles,
    Set<String>? selectedFileIds,
    Map<String, double>? downloadProgresses,
    String? sessionToken,
    List<Map<String, dynamic>>? pendingRequests,
    bool? isPaused,
    Set<String>? pausedDownloads,
  }) {
    return ClientState(
      availableLobbies: availableLobbies ?? this.availableLobbies,
      connectedLobby: connectedLobby ?? this.connectedLobby,
      isScanning: isScanning ?? this.isScanning,
      deviceId: deviceId ?? this.deviceId,
      isApproved: isApproved ?? this.isApproved,
      isCoHost: isCoHost ?? this.isCoHost,
      hostHttpPort: hostHttpPort ?? this.hostHttpPort,
      availableFiles: availableFiles ?? this.availableFiles,
      selectedFileIds: selectedFileIds ?? this.selectedFileIds,
      downloadProgresses: downloadProgresses ?? this.downloadProgresses,
      sessionToken: sessionToken ?? this.sessionToken,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      isPaused: isPaused ?? this.isPaused,
      pausedDownloads: pausedDownloads ?? this.pausedDownloads,
    );
  }
}

class ClientNotifier extends StateNotifier<ClientState> {
  ClientNotifier() : super(ClientState(deviceId: const Uuid().v4()));

  final DiscoveryService _discoveryService = DiscoveryService();
  final TcpClient _quicClient = TcpClient();
  String _lastSaveDirectory = '';

  void startScanning() {
    state = state.copyWith(isScanning: true);
    _discoveryService.startScanning();
    _discoveryService.lobbiesStream.listen((lobbies) {
      state = state.copyWith(availableLobbies: lobbies);
    });
  }

  void stopScanning() {
    _discoveryService.stopScanning();
    state = state.copyWith(isScanning: false);
  }

  Future<void> joinLobby(Lobby lobby, String deviceName, {String? pin}) async {
    try {
      await _quicClient.connect(lobby.hostIp, lobby.port);

      _quicClient.onMessageReceived = _handleServerMessage;

      final requestData = <String, dynamic>{
        'command': 'join_request',
        'deviceId': state.deviceId,
        'deviceName': deviceName,
      };
      
      if (pin != null && pin.isNotEmpty) {
        requestData['pin'] = pin;
      }

      _quicClient.sendMessage(requestData);

      state = state.copyWith(connectedLobby: lobby);
    } catch (e) {
      debugPrint('Failed to join lobby: $e');
    }
  }

  void _handleServerMessage(Map<String, dynamic> message) {
    final command = message['command'];
    if (command == 'join_approved') {
      state = state.copyWith(
        isApproved: true, 
        hostHttpPort: message['httpPort'],
        sessionToken: message['sessionToken'],
      );
    } else if (command == 'join_rejected') {
      leaveLobby();
    } else if (command == 'promote_cohost') {
      state = state.copyWith(isCoHost: true);
    } else if (command == 'file_list_update') {
      final files = List<Map<String, dynamic>>.from(message['files']);
      state = state.copyWith(availableFiles: files);
    } else if (command == 'pending_requests_update') {
      final requests = List<Map<String, dynamic>>.from(message['requests']);
      state = state.copyWith(pendingRequests: requests);
    } else if (command == 'lobby_state_update') {
      state = state.copyWith(isPaused: message['isPaused'] ?? false);
    }
  }

  void togglePauseDownload(String fileId) {
    if (state.pausedDownloads.contains(fileId)) {
      state = state.copyWith(
        pausedDownloads: state.pausedDownloads.where((id) => id != fileId).toSet(),
      );
      final file = state.availableFiles.firstWhere((f) => f['fileId'] == fileId, orElse: () => <String, dynamic>{});
      if (file.isNotEmpty) {
        _downloadSingleFile(file['fileName'], fileId, _lastSaveDirectory, file['checksum'] ?? '');
      }
    } else {
      state = state.copyWith(
        pausedDownloads: {...state.pausedDownloads, fileId},
      );
    }
  }

  void toggleFileSelection(String fileId) {
    final newSelection = Set<String>.from(state.selectedFileIds);
    if (newSelection.contains(fileId)) {
      newSelection.remove(fileId);
    } else {
      newSelection.add(fileId);
    }
    state = state.copyWith(selectedFileIds: newSelection);
  }

  void selectAll() {
    final allIds = state.availableFiles.map((f) => f['fileId'] as String).toSet();
    state = state.copyWith(selectedFileIds: allIds);
  }

  void clearSelection() {
    state = state.copyWith(selectedFileIds: {});
  }

  String _getFileUrl(String fileId) {
    if (state.connectedLobby == null) return '';
    return 'http://${state.connectedLobby!.hostIp}:${state.hostHttpPort}/download?fileId=$fileId';
  }

  Future<void> downloadSelectedFiles(String saveDirectory) async {
    _lastSaveDirectory = saveDirectory;
    final filesToDownload = state.availableFiles.where((f) => state.selectedFileIds.contains(f['fileId'])).toList();
    
    // Start downloads in parallel
    for (final file in filesToDownload) {
      _downloadSingleFile(file['fileName'], file['fileId'], saveDirectory, file['checksum'] ?? '');
    }
    clearSelection();
  }

  Future<void> downloadAllFiles(String saveDirectory) async {
    _lastSaveDirectory = saveDirectory;
    for (final file in state.availableFiles) {
      _downloadSingleFile(file['fileName'], file['fileId'], saveDirectory, file['checksum'] ?? '');
    }
  }

  Future<void> _downloadSingleFile(String fileName, String fileId, String saveDirectory, String expectedChecksum) async {
    state = state.copyWith(
      downloadProgresses: {...state.downloadProgresses, fileId: 0.0},
    );

    try {
      final file = await _quicClient.downloadFile(
        fileId, 
        state.sessionToken ?? '', 
        fileName, 
        (progress) {
          state = state.copyWith(
            downloadProgresses: {...state.downloadProgresses, fileId: progress},
          );
        }
      );
      
      if (file != null) {
        // Verify checksum
        final bytes = await file.readAsBytes();
        final actualChecksum = sha256.convert(bytes).toString(); 
        if (actualChecksum == expectedChecksum) {
          debugPrint('File downloaded via TCP and verified: ${file.path}');
          await DatabaseHelper.instance.insertTransferHistory(
            TransferHistory(
              transferId: const Uuid().v4(),
              fileName: fileName,
              fileSize: await file.length(),
              senderName: state.connectedLobby?.hostDeviceName ?? 'Unknown',
              direction: 'DOWNLOAD',
              status: 'COMPLETED',
              completedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        } else {
          debugPrint('Checksum mismatch!');
          // ... error handling
        }
      }
    } catch (e) {
      debugPrint('TCP download error for $fileName: $e');
    } finally {
       state = state.copyWith(
         downloadProgresses: {...state.downloadProgresses, fileId: 1.0},
       );
    }
  }

  void leaveLobby() {
    _quicClient.disconnect();
    state = ClientState(
      deviceId: state.deviceId,
      availableLobbies: state.availableLobbies,
      isScanning: state.isScanning,
    );
  }

  // Co-host actions
  Future<void> uploadFile(File file) async {
    if (!state.isCoHost || state.connectedLobby == null) return;
    
    try {
      // TODO: Refactor upload over QUIC-like UDP if requested, 
      // but keeping basic functionality or mocking for now.
      debugPrint('Upload over QUIC currently unsupported in simplified mock.');
    } catch (e) {
      debugPrint('Failed to upload file: $e');
    }
  }

  void removeFile(String fileId) {
    if (!state.isCoHost) return;
    _quicClient.sendMessage({
      'command': 'remove_file',
      'fileId': fileId,
    });
  }

  void approveJoinRequest(String requestId) {
    if (!state.isCoHost) return;
    _quicClient.sendMessage({
      'command': 'approve_request',
      'requestId': requestId,
    });
  }

  void rejectJoinRequest(String requestId) {
    if (!state.isCoHost) return;
    _quicClient.sendMessage({
      'command': 'reject_request',
      'requestId': requestId,
    });
  }

  void requestCoHost() {
    _quicClient.sendMessage({
      'command': 'request_cohost',
    });
  }

  void toggleLobbyPause(bool pause) {
    if (!state.isCoHost) return;
    // Optimistic UI update
    state = state.copyWith(isPaused: pause);
    _quicClient.sendMessage({
      'command': pause ? 'pause_lobby' : 'unpause_lobby',
    });
  }
}
