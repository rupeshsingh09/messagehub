import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';

class SocketService {
  SocketService._internal();
  static final SocketService instance = SocketService._internal();

  IO.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  // ===========================
  // 🔌 CONNECT
  // ===========================
  void connect() {
    if (_socket != null && _socket!.connected) return;

    final String serverUrl = ApiService.baseUrl;

    print('[Socket] 🌐 Connecting to: $serverUrl');

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket']) // important
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.connect();

    // ✅ Debug logs
    _socket!.onConnect((_) {
      print('[Socket] ✅ Connected | id: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      print('[Socket] ❌ Disconnected');
    });

    _socket!.onConnectError((err) {
      print('[Socket] ⚠️ Connect Error: $err');
    });

    _socket!.onReconnect((_) {
      print('[Socket] 🔄 Reconnected');
    });
  }

  // ===========================
  // 🔌 DISCONNECT
  // ===========================
  void disconnect() {
    print('[Socket] 🛑 Disconnecting...');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  // ===========================
  // 🧑 JOIN ROOM
  // ===========================
  void joinRoom(String userId) {
    if (_socket == null || !_socket!.connected) {
      print('[Socket] ⚠️ Cannot join, not connected');
      return;
    }

    _socket!.emit('join', userId);
    print('[Socket] 📤 Joined room: $userId');
  }

  // ===========================
  // 💬 SEND MESSAGE
  // ===========================
  void sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
    String? imageUrl,
  }) {
    if (_socket == null || !_socket!.connected) {
      print('[Socket] ⚠️ Cannot send message, not connected');
      return;
    }

    final payload = {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'imageUrl': imageUrl,
    };

    _socket!.emit('send_message', payload);

    print('[Socket] 📤 send_message: $payload');
  }

  // ===========================
  // 📩 RECEIVE MESSAGE
  // ===========================
  void onReceiveMessage(Function(Map<String, dynamic>) callback) {
    _socket?.on('receive_message', (data) {
      print('[Socket] 📩 receive_message: $data');

      if (data is Map<String, dynamic>) {
        callback(data);
      } else if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  // ===========================
  // ⌨️ TYPING STATUS
  // ===========================
  void sendTypingStatus({
    required String senderId,
    required String receiverId,
    required bool isTyping,
  }) {
    if (_socket == null || !_socket!.connected) return;

    _socket!.emit(isTyping ? 'typing' : 'stop_typing', {
      'senderId': senderId,
      'receiverId': receiverId,
    });
  }

  void onTypingStatus({
    required Function(Map<String, dynamic>) onTyping,
    required Function(Map<String, dynamic>) onStopTyping,
  }) {
    _socket?.on('typing', (data) {
      onTyping(Map<String, dynamic>.from(data));
    });

    _socket?.on('stop_typing', (data) {
      onStopTyping(Map<String, dynamic>.from(data));
    });
  }

  // ===========================
  // 🧹 CLEANUP
  // ===========================
  void offChatEvents() {
    _socket?.off('receive_message');
    _socket?.off('typing');
    _socket?.off('stop_typing');
  }
}