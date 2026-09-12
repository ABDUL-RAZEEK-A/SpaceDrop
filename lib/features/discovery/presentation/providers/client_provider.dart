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
    );
  }
}

class ClientNotifier extends StateNotifier<ClientState> {
  ClientNotifier() : super(ClientState(deviceId: const Uuid().v4()));

  final DiscoveryService _discoveryService = DiscoveryService();
  final TcpClient _tcpClient = TcpClient();

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
      await _tcpClient.connect(lobby.hostIp, lobby.port);

      _tcpClient.onMessageReceived = _handleServerMessage;
      _tcpClient.onDisconnected = () {
        state = state.copyWith(
          connectedLobby: null, 
          isApproved: false, 
          isCoHost: false,
          availableFiles: [], 
          selectedFileIds: {},
          sessionToken: null,
        );
      };

      final requestData = <String, dynamic>{
        'command': 'join_request',
        'deviceId': state.deviceId,
        'deviceName': deviceName,
      };
      
      if (pin != null && pin.isNotEmpty) {
        requestData['pin'] = pin;
      }

      _tcpClient.sendMessage(requestData);

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
    final filesToDownload = state.availableFiles.where((f) => state.selectedFileIds.contains(f['fileId'])).toList();
    
    // Start downloads in parallel
    for (final file in filesToDownload) {
      _downloadSingleFile(file['fileName'], file['fileId'], saveDirectory, file['checksum'] ?? '');
    }
    clearSelection();
  }

  Future<void> downloadAllFiles(String saveDirectory) async {
    for (final file in state.availableFiles) {
      _downloadSingleFile(file['fileName'], file['fileId'], saveDirectory, file['checksum'] ?? '');
    }
  }

  Future<void> _downloadSingleFile(String fileName, String fileId, String saveDirectory, String expectedChecksum) async {
    state = state.copyWith(
      downloadProgresses: {...state.downloadProgresses, fileId: 0.0},
    );

    try {
      final savePath = p.join(saveDirectory, fileName);
      final finalFile = File(savePath);
      
      final httpClient = HttpClient();
      final url = _getFileUrl(fileId);
      final uri = Uri.parse('$url&token=${state.sessionToken ?? ''}');
      
      // Step 1: Get the file size using HEAD request
      final sizeRequest = await httpClient.headUrl(uri);
      final sizeResponse = await sizeRequest.close();
      
      int totalBytes = 0;
      if (sizeResponse.statusCode == 200 || sizeResponse.statusCode == 206) {
        totalBytes = sizeResponse.contentLength;
      }
      
      if (totalBytes <= 0) {
        throw Exception("Could not determine file size or file is empty");
      }

      final int maxConcurrent = 4;
      final int chunkSize = (totalBytes / maxConcurrent).ceil();
      int totalReceived = 0;
      
      List<Future<void>> downloadTasks = [];
      List<File> tempFiles = [];
      
      final tempDir = await Directory.systemTemp.createTemp('spacedrop_down_');

      for (int i = 0; i < maxConcurrent; i++) {
        final start = i * chunkSize;
        if (start >= totalBytes) break;
        
        final end = (start + chunkSize - 1) < totalBytes ? (start + chunkSize - 1) : totalBytes - 1;
        final tempFile = File(p.join(tempDir.path, 'chunk_$i'));
        tempFiles.add(tempFile);
        
        downloadTasks.add(_downloadChunk(uri, start, end, tempFile, (chunkReceived) {
          totalReceived += chunkReceived;
          state = state.copyWith(
            downloadProgresses: {...state.downloadProgresses, fileId: totalReceived / totalBytes},
          );
        }));
      }
      
      // Wait for all chunks to download concurrently
      await Future.wait(downloadTasks);
      
      // Concatenate chunks sequentially into the final file
      final sink = finalFile.openWrite();
      for (var tempFile in tempFiles) {
        await sink.addStream(tempFile.openRead());
        await tempFile.delete(); // Clean up temp file
      }
      await sink.flush();
      await sink.close();
      await tempDir.delete();
      
      // Verify SHA-256 checksum
      final bytes = await finalFile.readAsBytes();
      final actualChecksum = sha256.convert(bytes).toString(); 
      if (actualChecksum == expectedChecksum) {
        debugPrint('File downloaded concurrently and verified: ${finalFile.path}');
        await DatabaseHelper.instance.insertTransferHistory(
          TransferHistory(
            transferId: const Uuid().v4(),
            fileName: fileName,
            fileSize: totalBytes,
            senderName: state.connectedLobby?.hostDeviceName ?? 'Unknown',
            direction: 'DOWNLOAD',
            status: 'COMPLETED',
            completedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } else {
        debugPrint('File downloaded but checksum mismatch! Expected $expectedChecksum, got $actualChecksum');
        await DatabaseHelper.instance.insertTransferHistory(
          TransferHistory(
            transferId: const Uuid().v4(),
            fileName: fileName,
            fileSize: totalBytes,
            senderName: state.connectedLobby?.hostDeviceName ?? 'Unknown',
            direction: 'DOWNLOAD',
            status: 'FAILED',
            completedAt: DateTime.now().millisecondsSinceEpoch,
            errorReason: 'Checksum mismatch',
          ),
        );
      }
    } catch (e) {
      debugPrint('Concurrent download error for $fileName: $e');
    } finally {
       state = state.copyWith(
         downloadProgresses: {...state.downloadProgresses, fileId: 1.0},
       );
    }
  }

  Future<void> _downloadChunk(Uri uri, int start, int end, File tempFile, Function(int) onProgress) async {
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(uri);
    request.headers.add('Range', 'bytes=$start-$end');
    final response = await request.close();
    
    if (response.statusCode == 200 || response.statusCode == 206) {
      final sink = tempFile.openWrite();
      await for (var chunk in response) {
        sink.add(chunk);
        onProgress(chunk.length);
      }
      await sink.flush();
      await sink.close();
    } else {
      throw Exception('Failed to download chunk $start-$end: ${response.statusCode}');
    }
  }

  void leaveLobby() {
    _tcpClient.disconnect();
    state = state.copyWith(
      connectedLobby: null, 
      isApproved: false, 
      isCoHost: false,
      availableFiles: [], 
      selectedFileIds: {},
      pendingRequests: [],
    );
  }

  // Co-host actions
  Future<void> uploadFile(File file) async {
    if (!state.isCoHost || state.connectedLobby == null) return;
    
    try {
      final hostIp = state.connectedLobby!.hostIp;
      final httpPort = state.hostHttpPort;
      final token = state.sessionToken ?? '';
      
      final httpClient = HttpClient();
      final uri = Uri.parse('http://$hostIp:$httpPort/upload?token=$token');
      final request = await httpClient.postUrl(uri);
      
      request.headers.add('X-File-Name', p.basename(file.path));
      request.headers.contentType = ContentType.binary;
      request.headers.contentLength = await file.length();
      
      await file.openRead().pipe(request);
      final response = await request.done;
      
      if (response.statusCode != 200) {
        debugPrint('Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to upload file: $e');
    }
  }

  void removeFile(String fileId) {
    if (!state.isCoHost) return;
    _tcpClient.sendMessage({
      'command': 'remove_file',
      'fileId': fileId,
    });
  }

  void approveJoinRequest(String requestId) {
    if (!state.isCoHost) return;
    _tcpClient.sendMessage({
      'command': 'approve_request',
      'requestId': requestId,
    });
  }

  void rejectJoinRequest(String requestId) {
    if (!state.isCoHost) return;
    _tcpClient.sendMessage({
      'command': 'reject_request',
      'requestId': requestId,
    });
  }
}
