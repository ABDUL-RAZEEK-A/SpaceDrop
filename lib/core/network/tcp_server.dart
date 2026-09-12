import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

typedef ConnectionCallback = void Function(Socket client, Map<String, dynamic> request);
typedef FileRequestCallback = File? Function(String? fileId);
typedef TokenValidationCallback = bool Function(String? token);
typedef UploadValidationCallback = bool Function(String? token);
typedef FileUploadedCallback = Future<void> Function(File file);

class TcpServer {
  ServerSocket? _serverSocket;
  HttpServer? _httpServer;
  
  int get tcpPort => _serverSocket?.port ?? 0;
  int get httpPort => _httpServer?.port ?? 0;
  
  final List<Socket> _clients = [];

  ConnectionCallback? onMessageReceived;
  FileRequestCallback? onFileRequested;
  TokenValidationCallback? onTokenValidated;
  UploadValidationCallback? onUploadRequested;
  FileUploadedCallback? onFileUploaded;

  Future<void> startServers() async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    debugPrint('TCP Server started on port ${_serverSocket!.port}');

    _serverSocket!.listen((Socket client) {
      _clients.add(client);
      debugPrint('Client connected: ${client.remoteAddress.address}:${client.remotePort}');

      client
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (String line) {
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            if (onMessageReceived != null) {
              onMessageReceived!(client, json);
            }
          } catch (e) {
            debugPrint('Error parsing message from client: $e');
          }
        },
        onError: (error) {
          debugPrint('Client error: $error');
          client.close();
          _clients.remove(client);
        },
        onDone: () {
          debugPrint('Client disconnected');
          client.close();
          _clients.remove(client);
        },
      );
    });

    _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    debugPrint('HTTP Server started on port ${_httpServer!.port}');
    
    _httpServer!.listen((HttpRequest request) async {
      if (request.uri.path == '/download') {
        final fileId = request.uri.queryParameters['fileId'];
        final token = request.uri.queryParameters['token'];

        // Token Validation
        if (onTokenValidated != null && !onTokenValidated!(token)) {
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.close();
          return;
        }
        File? file;
        if (onFileRequested != null) {
          file = onFileRequested!(fileId);
        }
        
        if (file != null && await file.exists()) {
          try {
            final fileLength = await file.length();
            final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
            
            if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
              final range = rangeHeader.substring(6).split('-');
              final start = int.tryParse(range[0]) ?? 0;
              final end = range.length > 1 && range[1].isNotEmpty 
                  ? int.tryParse(range[1]) ?? (fileLength - 1) 
                  : (fileLength - 1);

              if (start >= fileLength || end >= fileLength || start > end) {
                request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
                request.response.close();
                return;
              }

              request.response.statusCode = HttpStatus.partialContent;
              request.response.headers.contentType = ContentType.binary;
              request.response.headers.add('Content-Range', 'bytes $start-$end/$fileLength');
              request.response.headers.add('Content-Length', (end - start + 1).toString());
              request.response.headers.add('Accept-Ranges', 'bytes');
              
              await file.openRead(start, end + 1).pipe(request.response);
            } else {
              request.response.headers.contentType = ContentType.binary;
              request.response.headers.add('Content-Length', fileLength.toString());
              request.response.headers.add('Accept-Ranges', 'bytes');
              await file.openRead().pipe(request.response);
            }
          } catch (e) {
            debugPrint('Error serving file: $e');
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.close();
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.close();
        }
      } else if (request.uri.path == '/upload' && request.method == 'POST') {
        final token = request.uri.queryParameters['token'];
        final fileName = request.headers.value('X-File-Name');

        if (onUploadRequested == null || !onUploadRequested!(token)) {
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.close();
          return;
        }

        if (fileName == null || fileName.isEmpty) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.close();
          return;
        }

        try {
          // Write to a temporary file
          final tempDir = Directory.systemTemp.createTempSync('spacedrop_');
          final tempFile = File(p.join(tempDir.path, fileName));
          final sink = tempFile.openWrite();
          await for (var chunk in request) {
            sink.add(chunk);
          }
          await sink.close();

          if (onFileUploaded != null) {
            await onFileUploaded!(tempFile);
          }

          request.response.statusCode = HttpStatus.ok;
          request.response.write('Upload successful');
          request.response.close();
        } catch (e) {
          debugPrint('Error uploading file: $e');
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.close();
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
      }
    });
  }

  void stopServers() {
    for (var client in _clients) {
      client.close();
    }
    _clients.clear();
    _serverSocket?.close();
    _serverSocket = null;
    
    _httpServer?.close(force: true);
    _httpServer = null;
    
    debugPrint('TCP & HTTP Servers stopped');
  }

  void sendMessage(Socket client, Map<String, dynamic> message) {
    try {
      client.writeln(jsonEncode(message));
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  void broadcastMessage(Map<String, dynamic> message) {
    final jsonStr = jsonEncode(message);
    for (var client in _clients) {
      try {
        client.writeln(jsonStr);
      } catch (e) {
        debugPrint('Error broadcasting message to client: $e');
      }
    }
  }
}
