import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';
import '../config/app_config.dart';

class SocketService {
  SocketService._internal();
  static final SocketService instance = SocketService._internal();

  IO.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  // ===========================
  // 🔌 CONNECT
  // ===========================
  void connect(String userId) {
    if (_socket != null && _socket!.connected) {
      print('[Socket] ℹ️ Already connected');
      return;
    }

    final String serverUrl = AppConfig.socketUrl;

    print('[Socket] 🌐 Connecting to: $serverUrl');

    // If socket exists but not connected, we might want to dispose and recreate 
    // to ensure clean state and no duplicate listeners from previous attempts
    if (_socket != null) {
      _socket!.dispose();
    }

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(3000)
          .build(),
    );

    _socket!.onConnect((_) {
      print('[Socket] ✅ Socket connected | id: ${_socket!.id}');
      joinRoom(userId);
    });

    _socket!.onDisconnect((_) {
      print('[Socket] ❌ Disconnected');
    });

    _socket!.onConnectError((err) {
      print('[Socket] ⚠️ Connect Error: $err');
    });

    _socket!.onReconnect((_) {
      print('[Socket] 🔄 Reconnected');
      joinRoom(userId);
    });

    _socket!.connect();
  }

  // ===========================
  // 🔌 DISCONNECT
  // ===========================
  void disconnect() {
    print('[Socket] 🛑 Disconnecting...');
    if (_socket != null) {
      _socket!.offAny(); // Clear all listeners
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
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
    print('[Socket] ✅ Joined room: $userId');
  }

  // ===========================
  // 💬 SEND MESSAGE
  // ===========================
  void sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
    String? imageUrl,
    String? audioUrl,
    String? type,
    String? replyToId,
    String? replyText,
    String? replyType,
  }) {
    if (_socket == null || !_socket!.connected) {
      print('[Socket] ⚠️ Cannot send message, not connected');
      return;
    }

    final payload = {
      'sender': senderId,
      'receiver': receiverId,
      'message': message,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'type': type ?? 'text',
      'replyToId': replyToId,
      'replyText': replyText,
      'replyType': replyType,
    };

    _socket!.emit('send_message', payload);
    print('[Socket] 📤 Message emitted: $payload');
  }

  // ===========================
  // 📩 RECEIVE MESSAGE
  // ===========================
  void onReceiveMessage(Function(Map<String, dynamic>) callback) {
    _socket?.off('receive_message'); // Clear existing to prevent duplicates
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
    _socket?.off('typing');
    _socket?.off('stop_typing');

    _socket?.on('typing', (data) {
      onTyping(Map<String, dynamic>.from(data));
    });

    _socket?.on('stop_typing', (data) {
      onStopTyping(Map<String, dynamic>.from(data));
    });
  }

  // ===========================
  // ✅ MESSAGE STATUS
  // ===========================
  void updateMessageStatus({
    required String messageId,
    required String senderId,
    required String receiverId,
    required String status,
  }) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('update_status', {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
      'status': status,
    });
  }

  void onMessageStatus(Function(Map<String, dynamic>) callback) {
    _socket?.off('status_updated');
    _socket?.on('status_updated', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  // ===========================
  // 🗑 DELETE MESSAGE
  // ===========================
  void onMessageDeleted(Function(Map<String, dynamic>) callback) {
    _socket?.off('message_deleted');
    _socket?.on('message_deleted', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  // ===========================
  // 🖼 PROFILE UPDATES
  // ===========================
  void emitProfileUpdate(Map<String, dynamic> data) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('update_profile', data);
    print('[Socket] 🖼 Profile update emitted: $data');
  }

  // ===========================
  // 🟢 USER STATUS (ONLINE/LAST SEEN)
  // ===========================
  void onUserStatus(Function(Map<String, dynamic>) callback) {
    _socket?.off('user_status');
    _socket?.on('user_status', (data) {
      print('[Socket] 🟢 user_status: $data');
      callback(Map<String, dynamic>.from(data));
    });
  }

  // ===========================
  // 🧹 CLEANUP
  // ===========================
  void offChatEvents() {
    print('[Socket] 🧹 Clearing all chat listeners');
    _socket?.off('receive_message');
    _socket?.off('typing');
    _socket?.off('stop_typing');
    _socket?.off('user_status');
    _socket?.off('status_updated');
    _socket?.off('message_deleted');
  }
}