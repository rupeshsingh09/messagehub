import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';

class SocketService {
  SocketService._internal();
  static final SocketService instance = SocketService._internal();

  IO.Socket? _socket;
  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    if (_socket != null && _socket!.connected) return;

    // Use the same IP as ApiService
    final String serverUrl = 'http://${ApiService.serverIp}:5000';

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) => print('[Socket] ✅ Connected'));
    _socket!.onDisconnect((_) => print('[Socket] ❌ Disconnected'));
    _socket!.onConnectError((err) => print('[Socket] ⚠️ Connect Error: $err'));
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void joinRoom(String userId) {
    if (_socket == null) return;
    _socket!.emit('join', userId);
    print('[Socket] 📤 Joined room: $userId');
  }

  void sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
    String? imageUrl,
  }) {
    if (_socket == null || !_socket!.connected) return;
    
    _socket!.emit('send_message', {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'imageUrl': imageUrl,
    });
  }

  void onReceiveMessage(Function(Map<String, dynamic>) callback) {
    _socket?.on('receive_message', (data) {
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

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
    _socket?.on('typing', (data) => onTyping(Map<String, dynamic>.from(data)));
    _socket?.on('stop_typing', (data) => onStopTyping(Map<String, dynamic>.from(data)));
  }

  void offChatEvents() {
    _socket?.off('receive_message');
    _socket?.off('typing');
    _socket?.off('stop_typing');
  }
}
