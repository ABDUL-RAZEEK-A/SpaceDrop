import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

typedef ConnectionCallback = void Function(Map<String, dynamic> request, InternetAddress address, int port);
typedef FileRequestCallback = File? Function(String? fileId);
typedef TokenValidationCallback = bool Function(String? token);
typedef UploadValidationCallback = bool Function(String? token);
typedef FileUploadedCallback = Future<void> Function(File file);

class DownloadTask {
  final Socket socket;
  final String fileId;
  final File file;
  final int totalLength;
  late final StreamController<List<int>> streamController;
  int currentOffset = 0;
  bool isCompleted = false;

  DownloadTask({
    required this.socket,
    required this.fileId,
    required this.file,
    required this.totalLength,
  }) {
    streamController = StreamController<List<int>>(
      onListen: () {},
      onPause: () {},
      onResume: () {},
      onCancel: () {
        isCompleted = true;
      },
    );
    streamController.stream.pipe(socket).catchError((e) {
      isCompleted = true;
    });
  }
}

class TcpServer {
  ServerSocket? _serverSocket;
  int get port => _serverSocket?.port ?? 0;

  ConnectionCallback? onMessageReceived;
  FileRequestCallback? onFileRequested;
  TokenValidationCallback? onTokenValidated;
  UploadValidationCallback? onUploadRequested;
  FileUploadedCallback? onFileUploaded;

  final Map<String, Socket> _activeControlSockets = {}; // key: "ip:port"
  
  final List<DownloadTask> _activeDownloads = [];
  bool _isBroadcasting = false;
  final Map<String, RandomAccessFile> _openFiles = {};

  Future<void> startServers() async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    debugPrint('TCP Server started on port ${_serverSocket!.port}');

    _serverSocket!.listen((Socket socket) {
      _handleNewConnection(socket);
    });
  }

  void _handleNewConnection(Socket socket) {
    bool isFirstMessage = true;
    bool isControlConnection = false;
    List<int> buffer = [];

    final ipPort = '${socket.remoteAddress.address}:${socket.remotePort}';

    socket.listen(
      (Uint8List data) async {
        buffer.addAll(data);

        while (buffer.length >= 4) {
          final lengthBytes = Uint8List.fromList(buffer.sublist(0, 4));
          final payloadLength = ByteData.sublistView(lengthBytes).getUint32(0);

          if (buffer.length >= 4 + payloadLength) {
            final payloadBytes = buffer.sublist(4, 4 + payloadLength);
            buffer = buffer.sublist(4 + payloadLength);

            final payloadStr = utf8.decode(payloadBytes);
            Map<String, dynamic> json;
            try {
              json = jsonDecode(payloadStr);
            } catch (e) {
              debugPrint('Failed to decode JSON from socket: $e');
              continue;
            }

            if (isFirstMessage) {
              isFirstMessage = false;
              final type = json['type'] as String?;
              
              if (type == 'control_connect') {
                isControlConnection = true;
                _activeControlSockets[ipPort] = socket;
                debugPrint('Control connection established from $ipPort');
              } else if (type == 'download_request') {
                await _handleDownloadRequest(json, socket);
                return; // Download handled, socket closed
              }
            } else if (isControlConnection) {
              final type = json['type'] as String?;
              if (type == 'message') {
                if (onMessageReceived != null) {
                  onMessageReceived!(json['data'], socket.remoteAddress, socket.remotePort);
                }
              }
            }
          } else {
            break; // Wait for more data
          }
        }
      },
      onError: (e) {
        debugPrint('Socket error from $ipPort: $e');
        _activeControlSockets.remove(ipPort);
      },
      onDone: () {
        debugPrint('Socket closed from $ipPort');
        _activeControlSockets.remove(ipPort);
      },
    );
  }

  Future<void> _handleDownloadRequest(Map<String, dynamic> request, Socket socket) async {
    final fileId = request['fileId'];
    final token = request['token'];

    if (onTokenValidated != null && !onTokenValidated!(token)) {
      _sendFramedJson(socket, {'type': 'error', 'message': 'unauthorized'});
      await socket.flush();
      await socket.close();
      return;
    }

    File? file;
    if (onFileRequested != null) {
      file = onFileRequested!(fileId);
    }

    if (file != null && await file.exists()) {
      final length = await file.length();
      _sendFramedJson(socket, {
        'type': 'download_info',
        'length': length,
      });

      // Queue the file for round-robin broadcasting
      final task = DownloadTask(
        socket: socket,
        fileId: fileId,
        file: file,
        totalLength: length,
      );
      _activeDownloads.add(task);
      _startRoundRobinBroadcaster();
    } else {
      _sendFramedJson(socket, {'type': 'error', 'message': 'not_found'});
      await socket.flush();
      await socket.close();
    }
  }

  void _startRoundRobinBroadcaster() async {
    if (_isBroadcasting) return;
    _isBroadcasting = true;

    const chunkSize = 64 * 1024; // 64 KB per chunk per client

    while (_activeDownloads.isNotEmpty) {
      bool dataSentInThisRound = false;

      // Iterate through a copy in case the original list changes
      for (int i = 0; i < _activeDownloads.length; i++) {
        final task = _activeDownloads[i];

        if (task.isCompleted) continue;
        
        // Backpressure check: If the socket's buffer is full, the stream controller pauses.
        // We skip this client for this round so it doesn't block others!
        if (task.streamController.isPaused) continue;

        try {
          // Open exactly one RandomAccessFile per fileId if not already open
          if (!_openFiles.containsKey(task.fileId)) {
            _openFiles[task.fileId] = await task.file.open(mode: FileMode.read);
          }

          final raf = _openFiles[task.fileId]!;
          await raf.setPosition(task.currentOffset);
          final chunk = await raf.read(chunkSize);

          if (chunk.isNotEmpty) {
            task.streamController.add(chunk);
            task.currentOffset += chunk.length;
            dataSentInThisRound = true;

            if (task.currentOffset >= task.totalLength) {
              task.isCompleted = true;
              await task.streamController.close();
            }
          } else {
            task.isCompleted = true;
            await task.streamController.close();
          }
        } catch (e) {
          debugPrint('Error streaming to client: $e');
          task.isCompleted = true;
          await task.streamController.close();
        }
      }

      // Cleanup completed downloads
      _activeDownloads.removeWhere((t) => t.isCompleted);

      // Cleanup files that are no longer being downloaded by ANY client
      _openFiles.removeWhere((fileId, raf) {
        if (!_activeDownloads.any((t) => t.fileId == fileId)) {
          raf.close();
          return true;
        }
        return false;
      });

      if (!dataSentInThisRound && _activeDownloads.isNotEmpty) {
        // All active downloads are either paused (slow network) or empty.
        // Small delay to prevent burning CPU in a tight loop.
        await Future.delayed(const Duration(milliseconds: 10));
      } else {
        // Yield to the event loop so control messages can still be processed instantly
        await Future.delayed(Duration.zero);
      }
    }

    _isBroadcasting = false;
  }

  void sendMessage(InternetAddress address, int port, Map<String, dynamic> message) {
    final ipPort = '${address.address}:$port';
    final socket = _activeControlSockets[ipPort];
    if (socket != null) {
      _sendFramedJson(socket, {'type': 'message', 'data': message});
    } else {
      debugPrint('Warning: Try to send message to $ipPort but no active control socket found.');
    }
  }

  void _sendFramedJson(Socket socket, Map<String, dynamic> data) {
    try {
      final payload = utf8.encode(jsonEncode(data));
      final lengthData = ByteData(4);
      lengthData.setUint32(0, payload.length);
      socket.add(lengthData.buffer.asUint8List());
      socket.add(payload);
    } catch (e) {
      debugPrint('Error sending framed json: $e');
    }
  }

  void stopServers() {
    for (var socket in _activeControlSockets.values) {
      socket.destroy();
    }
    _activeControlSockets.clear();
    
    for (var raf in _openFiles.values) {
      raf.close();
    }
    _openFiles.clear();
    for (var task in _activeDownloads) {
      task.streamController.close();
      task.socket.destroy();
    }
    _activeDownloads.clear();
    _isBroadcasting = false;
    
    _serverSocket?.close();
    _serverSocket = null;
    debugPrint('TCP Server stopped');
  }
}
