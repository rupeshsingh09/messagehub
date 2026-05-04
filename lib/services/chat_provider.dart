import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import 'api_service.dart';
import 'socket_service.dart';
import 'storage_service.dart';

class ChatProvider with ChangeNotifier {
  ChatUser? _currentUser;
  List<ChatUser> _users = [];
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;
  bool _isPartnerTyping = false;
  String? _activeChatPartnerId;

  ChatUser? get currentUser => _currentUser;
  List<ChatUser> get users => _users;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPartnerTyping => _isPartnerTyping;

  void setCurrentUser(ChatUser user) {
    _currentUser = user;
    StorageService.saveUser(user);
    SocketService.instance.connect();
    SocketService.instance.joinRoom(user.id);
    notifyListeners();
  }

  Future<void> loadUserLocally() async {
    final user = await StorageService.getUser();
    if (user != null) {
      _currentUser = user;
      SocketService.instance.connect();
      SocketService.instance.joinRoom(_currentUser!.id);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await StorageService.logout();
    _currentUser = null;
    _users = [];
    _messages = [];
    _error = null;
    _isPartnerTyping = false;
    _activeChatPartnerId = null;
    SocketService.instance.disconnect();
    notifyListeners();
  }

  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final success = await ApiService.sendOtp(phone);
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final user = await ApiService.verifyOtp(phone, otp);
    _isLoading = false;

    if (user != null) {
      _currentUser = user;
      StorageService.saveUser(user);
      SocketService.instance.connect();
      SocketService.instance.joinRoom(user.id);
      notifyListeners();
      return true;
    }

    _error = 'Invalid OTP';
    notifyListeners();
    return false;
  }

  // Requirement: Add register method using ApiService.registerUser
  Future<bool> register(String name, String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await ApiService.registerUser(name, phone);
      _isLoading = false;

      if (user != null) {
        _currentUser = user;
        StorageService.saveUser(user);
        SocketService.instance.connect();
        SocketService.instance.joinRoom(user.id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = 'Registration failed: $e';
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> fetchUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final allUsers = await ApiService.getUsers();
      
      final Map<String, ChatUser> uniqueUsers = {};
      for (var user in allUsers) {
        if (_currentUser != null && user.id == _currentUser!.id) continue;
        uniqueUsers[user.id] = user;
      }
      
      _users = uniqueUsers.values.toList();
    } catch (e) {
      _error = 'Failed to load users';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMessages(String receiverId) async {
    if (_currentUser == null) return;
    _activeChatPartnerId = receiverId;
    _isLoading = true;
    notifyListeners();

    try {
      _messages = await ApiService.getMessages(_currentUser!.id, receiverId);
      _listenForIncomingMessages();

      final userIndex = _users.indexWhere((u) => u.id == receiverId);
      if (userIndex != -1) {
        final user = _users[userIndex];
        _users[userIndex] = ChatUser(
          id: user.id,
          name: user.name,
          phone: user.phone,
          lastMessage: user.lastMessage,
          lastMessageTime: user.lastMessageTime,
          profilePic: user.profilePic,
          unreadCount: 0,
        );
      }
    } catch (e) {
      _error = 'Failed to load messages';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _listenForIncomingMessages() {
    SocketService.instance.offChatEvents();
    SocketService.instance.onReceiveMessage((data) {
      final senderId = data['senderId'] ?? data['sender'];
      final receiverId = data['receiverId'] ?? data['receiver'];
      
      if (senderId == _activeChatPartnerId && receiverId == _currentUser?.id) {
        final newMessage = Message(
          senderId: senderId,
          receiverId: receiverId,
          text: data['message'] ?? '',
          imageUrl: data['imageUrl'],
          timestamp: DateTime.now(),
          isMe: false,
        );
        _messages.add(newMessage);
        notifyListeners();
      }
      
      final userIndex = _users.indexWhere((u) => u.id == senderId);
      if (userIndex != -1) {
        final user = _users[userIndex];
        _users[userIndex] = ChatUser(
          id: user.id,
          name: user.name,
          phone: user.phone,
          lastMessage: data['message'],
          lastMessageTime: DateTime.now(),
          profilePic: user.profilePic,
          unreadCount: senderId == _activeChatPartnerId ? 0 : user.unreadCount + 1,
        );
        notifyListeners();
      }
    });

    SocketService.instance.onTypingStatus(
      onTyping: (data) {
        if (data['senderId'] == _activeChatPartnerId) {
          _isPartnerTyping = true;
          notifyListeners();
        }
      },
      onStopTyping: (data) {
        if (data['senderId'] == _activeChatPartnerId) {
          _isPartnerTyping = false;
          notifyListeners();
        }
      },
    );
  }

  Future<void> sendMessage(String receiverId, String text, {String? imageUrl}) async {
    if (_currentUser == null) return;

    try {
      final newMessage = Message(
        senderId: _currentUser!.id,
        receiverId: receiverId,
        text: text,
        imageUrl: imageUrl,
        timestamp: DateTime.now(),
        isMe: true,
      );
      _messages.add(newMessage);
      notifyListeners();

      // API call to persist
      final success = await ApiService.sendMessage(
        sender: _currentUser!.id,
        receiver: receiverId,
        message: text,
        imageUrl: imageUrl,
      );
      
      if (!success) {
        print('[ChatProvider] API send failed');
      }

      // Socket call for real-time
      SocketService.instance.sendMessage(
        senderId: _currentUser!.id,
        receiverId: receiverId,
        message: text,
        imageUrl: imageUrl,
      );

      // Update last message in local list
      final userIndex = _users.indexWhere((u) => u.id == receiverId);
      if (userIndex != -1) {
        final user = _users[userIndex];
        _users[userIndex] = ChatUser(
          id: user.id,
          name: user.name,
          phone: user.phone,
          lastMessage: text.isNotEmpty ? text : (imageUrl != null ? 'Photo' : ''),
          lastMessageTime: DateTime.now(),
          profilePic: user.profilePic,
          unreadCount: 0,
        );
        notifyListeners();
      }
    } catch (e) {
      print('[ChatProvider] Error in sendMessage: $e');
    }
  }

  // Requirement: Add sendImageMessage(receiverId, imageUrl)
  Future<void> sendImageMessage(String receiverId, String imageUrl) async {
    await sendMessage(receiverId, '', imageUrl: imageUrl);
  }

  void setTypingStatus(String receiverId, bool isTyping) {
    if (_currentUser == null) return;
    SocketService.instance.sendTypingStatus(
      senderId: _currentUser!.id,
      receiverId: receiverId,
      isTyping: isTyping,
    );
  }

  void clearActiveChat() {
    _activeChatPartnerId = null;
    _messages = [];
    _isPartnerTyping = false;
    SocketService.instance.offChatEvents();
    notifyListeners();
  }
}
