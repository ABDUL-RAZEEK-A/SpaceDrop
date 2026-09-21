import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class TcpClient {
  Socket? _controlSocket;
  String? _host;
  int? _port;
  
  Function(Map<String, dynamic>)? onMessageReceived;

  Future<void> connect(String host, int port) async {
    _host = host;
    _port = port;
    
    _controlSocket = await Socket.connect(host, port);
    debugPrint('TCP Client connected to $host:$port');
    
    _sendFramedJson(_controlSocket!, {'type': 'control_connect'});

    List<int> buffer = [];
    
    _controlSocket!.listen((Uint8List data) {
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
            continue;
          }

          final type = json['type'] as String?;
          if (type == 'message') {
            if (onMessageReceived != null) {
              onMessageReceived!(json['data']);
            }
          }
        } else {
          break; // Wait for more data
        }
      }
    }, onError: (e) {
      debugPrint('Control socket error: $e');
      disconnect();
    }, onDone: () {
      debugPrint('Control socket closed');
      disconnect();
    });
  }

  Future<File?> downloadFile(String fileId, String token, String fileName, Function(double) onProgress) async {
    if (_host == null || _port == null) return null;

    final saveDir = await getApplicationDocumentsDirectory();
    final savePath = p.join(saveDir.path, fileName);
    final file = File(savePath);

    Socket? downloadSocket;
    IOSink? fileSink;
    
    try {
      downloadSocket = await Socket.connect(_host!, _port!);
      
      _sendFramedJson(downloadSocket, {
        'type': 'download_request',
        'fileId': fileId,
        'token': token,
      });

      final completer = Completer<bool>();
      List<int> headerBuffer = [];
      bool readingHeader = true;
      int expectedFileLength = 0;
      int receivedFileLength = 0;

      downloadSocket.listen((Uint8List data) async {
        if (readingHeader) {
          headerBuffer.addAll(data);
          
          if (headerBuffer.length >= 4) {
            final lengthBytes = Uint8List.fromList(headerBuffer.sublist(0, 4));
            final payloadLength = ByteData.sublistView(lengthBytes).getUint32(0);
            
            if (headerBuffer.length >= 4 + payloadLength) {
              final payloadBytes = headerBuffer.sublist(4, 4 + payloadLength);
              final payloadStr = utf8.decode(payloadBytes);
              
              try {
                final json = jsonDecode(payloadStr) as Map<String, dynamic>;
                if (json['type'] == 'download_info') {
                  expectedFileLength = json['length'] as int;
                  readingHeader = false;
                  fileSink = file.openWrite();
                  
                  // If there is extra data after the header, it's file data
                  final extraData = headerBuffer.sublist(4 + payloadLength);
                  if (extraData.isNotEmpty) {
                    fileSink!.add(extraData);
                    receivedFileLength += extraData.length;
                    onProgress(receivedFileLength / expectedFileLength);
                  }
                  
                  if (receivedFileLength >= expectedFileLength) {
                    await fileSink!.flush();
                    await fileSink!.close();
                    completer.complete(true);
                  }
                } else {
                  // Error from server
                  completer.complete(false);
                  downloadSocket?.close();
                }
              } catch (e) {
                completer.complete(false);
                downloadSocket?.close();
              }
            }
          }
        } else {
          // File data streaming
          if (fileSink != null) {
            fileSink!.add(data);
            receivedFileLength += data.length;
            onProgress(receivedFileLength / expectedFileLength);
            
            if (receivedFileLength >= expectedFileLength) {
              await fileSink!.flush();
              await fileSink!.close();
              completer.complete(true);
              downloadSocket?.close();
            }
          }
        }
      }, onError: (e) {
        debugPrint('Download socket error: $e');
        if (!completer.isCompleted) completer.complete(false);
      }, onDone: () {
        if (!completer.isCompleted) completer.complete(false);
      });

      final success = await completer.future;
      if (success) {
        return file;
      } else {
        await fileSink?.close();
        if (await file.exists()) await file.delete();
        return null;
      }
    } catch (e) {
      debugPrint('Error starting download: $e');
      await fileSink?.close();
      if (await file.exists()) await file.delete();
      return null;
    } finally {
      downloadSocket?.destroy();
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_controlSocket != null) {
      _sendFramedJson(_controlSocket!, {'type': 'message', 'data': message});
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

  void disconnect() {
    _controlSocket?.destroy();
    _controlSocket = null;
    _host = null;
    _port = null;
  }
}
