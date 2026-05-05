import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'api_service.dart';
import 'socket_service.dart';
import 'storage_service.dart';
import 'contact_service.dart';

class ChatProvider with ChangeNotifier {
  ChatUser? _currentUser;
  List<ChatUser> _users = [];
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;
  bool _isPartnerTyping = false;
  String? _activeChatPartnerId;
  String? _token;

  ChatUser? get currentUser => _currentUser;
  String? get token => _token;
  List<ChatUser> get users => _users;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPartnerTyping => _isPartnerTyping;

  // ===========================
  // 👤 USER SETUP
  // ===========================

  /// Call this after OTP verified — saves to SharedPreferences and connects socket.
  void setCurrentUser(ChatUser user, String? token) {
    _currentUser = user;
    _token = token;
    StorageService.saveUser(user, token);
    SocketService.instance.connect();
    SocketService.instance.joinRoom(user.id);
    notifyListeners();
  }

  /// Loads user from SharedPreferences on app start (called by SplashScreen indirectly).
  Future<void> loadUserLocally() async {
    final user = await StorageService.getUser();
    final token = await StorageService.getToken();
    if (user != null) {
      _currentUser = user;
      _token = token;
      SocketService.instance.connect();
      SocketService.instance.joinRoom(user.id);
      notifyListeners();
    }
  }

  /// Clears all user data, disconnects socket, and navigates to signup.
  Future<void> logout() async {
    await StorageService.logout();
    _currentUser = null;
    _token = null;
    _users = [];
    _messages = [];
    _error = null;
    _isPartnerTyping = false;
    _activeChatPartnerId = null;
    SocketService.instance.disconnect();
    notifyListeners();
  }

  // ===========================
  // 🔐 OTP AUTH FLOW
  // ===========================

  /// Step 1: Call /send-otp API — triggers OTP delivery.
  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await ApiService.sendOtp(phone);

    _isLoading = false;

    if (result['success'] == true) {
      notifyListeners();
      return true;
    }

    _error = result['message'] as String?;
    notifyListeners();
    return false;
  }

  /// Step 2: Call /verify-otp API — on success saves user & routes to home.
  Future<bool> loginWithOtp(String phone, String otp, String firstName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await ApiService.verifyOtp(phone, otp, firstName);

    _isLoading = false;

    if (result['success'] == true) {
      final ChatUser user = result['user'] as ChatUser;
      final String? token = result['token'] as String?;
      setCurrentUser(user, token); // saves to SharedPreferences + connects socket
      return true;
    }

    _error = result['message'] as String?;
    notifyListeners();
    return false;
  }

  // ===========================
  // 👥 USERS / CONTACTS
  // ===========================

  Future<void> fetchUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final List<dynamic> usersData = await ApiService.getUsers();

      if (usersData.isEmpty) {
        _users = [];
        print('[ChatProvider] No users found on server');
        return;
      }

      final Map<String, ChatUser> uniqueUsers = {};
      for (var data in usersData) {
        final user = ChatUser.fromJson(data);
        if (_currentUser != null && user.id == _currentUser!.id) continue;
        uniqueUsers[user.id] = user;
      }

      _users = uniqueUsers.values.toList();
      print('[ChatProvider] Successfully fetched ${_users.length} users');
    } catch (e) {
      print('[ChatProvider] Error fetching users: $e');
      _error = 'Failed to load users: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===========================
  // 👥 USERS / CONTACTS
  // ===========================

  /// Fetches device contacts, cleans them, and matches them with backend users.
  Future<void> fetchContactsAndMatch() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Get cleaned numbers from device
      final List<String> phoneNumbers = await ContactService.getDevicePhoneNumbers();

      if (phoneNumbers.isEmpty) {
        _users = [];
        _error = 'No contacts found on device';
        print('[ChatProvider] No device contacts to match');
        return;
      }

      // 2. Send to backend to find matched users
      // Requirement: Assign exactly like this
      final List<dynamic> matchedUsers = await ApiService.matchContacts(phoneNumbers);

      // 3. Handle empty state and convert to ChatUser objects
      if (matchedUsers.isEmpty) {
        _users = [];
        print('[ChatProvider] No matching users found for contacts');
      } else {
        _users = matchedUsers
            .map((data) => ChatUser.fromJson(data))
            .where((user) => _currentUser == null || user.id != _currentUser!.id)
            .toList();
      }
      
      print('[ChatProvider] Matched ${_users.length} contacts');
    } catch (e) {
      print('[ChatProvider] Error in fetchContactsAndMatch: $e');
      _error = e.toString().contains('denied') 
          ? 'Contacts permission denied. Please enable in settings.' 
          : 'Failed to match contacts: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===========================
  // 💬 MESSAGES
  // ===========================

  Future<void> fetchMessages(String receiverId) async {
    if (_currentUser == null) return;

    _activeChatPartnerId = receiverId;
    _isLoading = true;
    notifyListeners();

    try {
      _messages =
          await ApiService.getMessages(_currentUser!.id, receiverId);
      _listenForIncomingMessages();
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

      if (senderId == _activeChatPartnerId &&
          receiverId == _currentUser?.id) {
        _messages.add(
          Message(
            senderId: senderId,
            receiverId: receiverId,
            text: data['message'] ?? '',
            imageUrl: data['imageUrl'],
            timestamp: DateTime.now(),
            isMe: false,
          ),
        );
        notifyListeners();
      }
    });
  }

  Future<void> sendMessage(String receiverId, String text,
      {String? imageUrl}) async {
    if (_currentUser == null) return;

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

    await ApiService.sendMessage(
      sender: _currentUser!.id,
      receiver: receiverId,
      message: text,
      imageUrl: imageUrl,
    );

    SocketService.instance.sendMessage(
      senderId: _currentUser!.id,
      receiverId: receiverId,
      message: text,
      imageUrl: imageUrl,
    );
  }

  Future<void> sendImageMessage(String receiverId, String imageUrl) async {
    await sendMessage(receiverId, '', imageUrl: imageUrl);
  }
}