import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';

typedef MessageCallback = void Function(Map<String, dynamic> message);
typedef DisconnectCallback = void Function();

class TcpClient {
  Socket? _socket;
  MessageCallback? onMessageReceived;
  DisconnectCallback? onDisconnected;

  Future<void> connect(String host, int port) async {
    try {
      _socket = await Socket.connect(host, port);
      debugPrint('Connected to $host:$port');

      _socket!
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (String line) {
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            if (onMessageReceived != null) {
              onMessageReceived!(json);
            }
          } catch (e) {
            debugPrint('Error parsing message from server: $e');
          }
        },
        onError: (error) {
          debugPrint('Client socket error: $error');
          disconnect();
        },
        onDone: () {
          debugPrint('Server disconnected');
          disconnect();
        },
      );
    } catch (e) {
      debugPrint('Error connecting to $host:$port : $e');
      rethrow;
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    try {
      if (_socket != null) {
        _socket!.writeln(jsonEncode(message));
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  void disconnect() {
    _socket?.close();
    _socket = null;
    if (onDisconnected != null) {
      onDisconnected!();
    }
  }
}
