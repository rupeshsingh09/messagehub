import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../repositories/user_repository.dart';
import '../repositories/chat_repository.dart';
import '../services/socket_service.dart';
import '../services/storage_service.dart';
import '../services/contact_service.dart';
import '../services/audio_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class ChatProvider with ChangeNotifier {
  final UserRepository _userRepository = UserRepository();
  final ChatRepository _chatRepository = ChatRepository();
  final AudioService _audioService = AudioService();
  final _uuid = const Uuid();

  ChatUser? _currentUser;
  List<ChatUser> _users = [];
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isSendingMessage = false;
  String? _error;
  bool _isPartnerTyping = false;
  String? _token;
  String? _currentOpenChatUserId;

  // Search
  String _userSearchQuery = '';
  String _messageSearchQuery = '';
  
  // Reply
  Message? _replyToMessage;

  // Track unread counts
  Map<String, int> _unreadCounts = {};

  // Track user status
  Map<String, bool> _onlineStatus = {};
  Map<String, DateTime?> _lastSeenTimes = {};

  ChatUser? get currentUser => _currentUser;
  String? get token => _token;
  List<ChatUser> get users {
    if (_userSearchQuery.isEmpty) return _users;
    return _users.where((u) => u.name.toLowerCase().contains(_userSearchQuery.toLowerCase())).toList();
  }
  List<Message> get messages {
    if (_messageSearchQuery.isEmpty) return _messages;
    return _messages.where((m) => m.text.toLowerCase().contains(_messageSearchQuery.toLowerCase())).toList();
  }
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPartnerTyping => _isPartnerTyping;
  bool get isSendingMessage => _isSendingMessage;
  Map<String, int> get unreadCounts => _unreadCounts;
  String? get currentOpenChatUserId => _currentOpenChatUserId;
  Map<String, bool> get onlineStatus => _onlineStatus;
  Map<String, DateTime?> get lastSeenTimes => _lastSeenTimes;
  Message? get replyToMessage => _replyToMessage;
  AudioService get audioService => _audioService;
  bool get isRecording => _audioService.isRecording;

  // ===========================
  // 🎤 VOICE RECORDING LOGIC
  // ===========================

  Future<void> startRecording() async {
    print('[ChatProvider] 🎤 Recording started');
    final success = await _audioService.startRecording();
    _safeNotifyListeners();
  }

  Future<String?> stopRecording() async {
    print('[ChatProvider] 🛑 Recording stopped');
    final path = await _audioService.stopRecording();
    if (path != null) {
      print('[ChatProvider] 📍 Final audio path: $path');
    } else {
      print('[ChatProvider] ⚠️ stopRecording returned null path');
    }
    _safeNotifyListeners();
    return path;
  }

  // ===========================
  // 👤 USER SETUP
  // ===========================

  void setCurrentUser(ChatUser user, String? token) {
    _currentUser = user;
    _token = token;
    StorageService.saveUser(user, token);
    SocketService.instance.connect(user.id);
    _listenForIncomingMessages();
    _safeNotifyListeners();
  }

  Future<void> loadUserLocally() async {
    final user = await StorageService.getUser();
    final token = await StorageService.getToken();
    if (user != null) {
      _currentUser = user;
      _token = token;
      SocketService.instance.connect(user.id);
      _listenForIncomingMessages();
      _safeNotifyListeners();
    }
  }

  Future<void> logout() async {
    await StorageService.logout();
    _currentUser = null;
    _token = null;
    _users = [];
    _messages = [];
    _unreadCounts = {};
    _error = null;
    _isPartnerTyping = false;
    _currentOpenChatUserId = null;
    _onlineStatus = {};
    _lastSeenTimes = {};
    SocketService.instance.disconnect();
    _safeNotifyListeners();
  }

  Future<int> deleteAccount() async {
    _isLoading = true;
    _safeNotifyListeners();
    
    final success = await _userRepository.deleteAccount();
    
    if (success && _currentUser != null) {
      await StorageService.removeAccount(_currentUser!.id);
      
      SocketService.instance.disconnect();
      
      final savedAccounts = await StorageService.getSavedAccounts();
      
      if (savedAccounts.isNotEmpty) {
        await switchAccount(savedAccounts.first);
        _isLoading = false;
        _safeNotifyListeners();
        return 1; // Switched to another account
      } else {
        await logout();
        _isLoading = false;
        _safeNotifyListeners();
        return 2; // Completely logged out
      }
    }
    
    _isLoading = false;
    _safeNotifyListeners();
    return 0; // Failed
  }

  Future<void> updateBio(String bio) async {
    if (_currentUser == null) return;
    final success = await _userRepository.updateBio(bio);
    if (success) {
      _currentUser = _currentUser!.copyWith(bio: bio);
      await StorageService.saveUser(_currentUser!, _token);
      _safeNotifyListeners();
    }
  }

  // ===========================
  // 🖼 PROFILE PHOTO LOGIC
  // ===========================

  Future<void> updateProfilePhoto(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 512,
    );

    if (pickedFile != null) {
      _isLoading = true;
      _safeNotifyListeners();

      try {
        final result = await _userRepository.updateProfilePic(pickedFile.path);
        
        if (result['success'] == true) {
          final updatedUser = result['user'] as ChatUser;
          final imageUrl = result['profilePic'] as String;
          
          _currentUser = updatedUser;
          await StorageService.saveUser(_currentUser!, _token);
          
          SocketService.instance.emitProfileUpdate({
            'userId': _currentUser!.id,
            'profilePic': imageUrl,
          });
        } else {
          _error = result['message'] ?? 'Failed to upload photo';
        }
      } catch (e) {
        _error = 'Failed to update profile photo';
      } finally {
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  Future<void> removeProfilePhoto() async {
    _isLoading = true;
    _safeNotifyListeners();

    try {
      final success = await _userRepository.removeProfilePic();
      if (success) {
        _currentUser = _currentUser?.copyWith(profilePic: '');
        await StorageService.saveUser(_currentUser!, _token);
        
        SocketService.instance.emitProfileUpdate({
          'userId': _currentUser!.id,
          'profilePic': '',
        });
      }
    } catch (e) {
      print('[ChatProvider] Error removing profile photo: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // ===========================
  // 🔄 MULTI-ACCOUNT LOGIC
  // ===========================

  Future<List<Map<String, dynamic>>> getSavedAccounts() async {
    return await StorageService.getSavedAccounts();
  }

  Future<void> switchAccount(Map<String, dynamic> accountData) async {
    _isLoading = true;
    _safeNotifyListeners();

    try {
      SocketService.instance.disconnect();

      final user = ChatUser.fromJson(accountData['user']);
      final token = accountData['token'];

      _currentUser = user;
      _token = token;

      await StorageService.saveUser(user, token);

      SocketService.instance.connect(user.id);
      _listenForIncomingMessages();

      _users = [];
      _messages = [];
      _unreadCounts = {};
      _onlineStatus = {};
      _lastSeenTimes = {};
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // ===========================
  // 🔐 OTP AUTH FLOW
  // ===========================

  Future<bool> sendOtp(String phone) async {
    final String normalizedPhone = ContactService.cleanNumber(phone);
    print('[ChatProvider] 📲 Requesting OTP for phone: $normalizedPhone (original: $phone)');
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final result = await _userRepository.sendOtp(normalizedPhone);
      _isLoading = false;

      if (result['success'] == true) {
        print('[ChatProvider] ✅ OTP request successful: ${result['message']}');
        _safeNotifyListeners();
        return true;
      }

      _error = result['message'] as String?;
      print('[ChatProvider] ❌ OTP request failed: $_error');
      _safeNotifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Connection error. Please try again.';
      print('[ChatProvider] 💥 Exception in sendOtp: $e');
      _safeNotifyListeners();
      return false;
    }
  }

  Future<bool> loginWithOtp(String phone, String otp, String firstName) async {
    final String normalizedPhone = ContactService.cleanNumber(phone);
    print('[ChatProvider] 🔐 Verifying OTP for phone: $normalizedPhone');
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final result = await _userRepository.verifyOtp(normalizedPhone, otp, firstName);
      _isLoading = false;

      if (result['success'] == true) {
        print('[ChatProvider] ✅ OTP verification successful');
        ChatUser newUser = result['user'] as ChatUser;
        final String? token = result['token'] as String?;

        if (newUser.name.trim().isEmpty && firstName.trim().isNotEmpty) {
          newUser = newUser.copyWith(name: firstName.trim());
        }

        // Prevent duplicate account creation by reusing the local account
        final savedAccounts = await StorageService.getSavedAccounts();
        final existingAccountIndex = savedAccounts.indexWhere((acc) {
          final u = ChatUser.fromJson(acc['user']);
          return u.phone == phone;
        });

        if (existingAccountIndex != -1) {
          final existingUser = ChatUser.fromJson(savedAccounts[existingAccountIndex]['user']);
          final newName = newUser.name.trim().isNotEmpty ? newUser.name : existingUser.name;
          final updatedExistingUser = existingUser.copyWith(
             name: newName,
             profilePic: newUser.profilePic,
             bio: newUser.bio,
          );
          setCurrentUser(updatedExistingUser, token);
          return true;
        }

        setCurrentUser(newUser, token);
        return true;
      }

      _error = result['message'] as String?;
      print('[ChatProvider] ❌ OTP verification failed: $_error');
      _safeNotifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Verification failed. Check your connection.';
      print('[ChatProvider] 💥 Exception in loginWithOtp: $e');
      _safeNotifyListeners();
      return false;
    }
  }

  // ===========================
  // 👥 USERS / CONTACTS
  // ===========================

  Future<void> fetchUsers() async {
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final List<ChatUser> fetchedUsers = await _userRepository.getUsers();

      if (fetchedUsers.isEmpty) {
        _users = [];
        return;
      }

      final Map<String, ChatUser> uniqueUsers = {};
      for (var user in fetchedUsers) {
        if (_currentUser != null && user.id == _currentUser!.id) continue;
        uniqueUsers[user.id] = user;
        
        _onlineStatus[user.id] = user.isOnline;
        _lastSeenTimes[user.id] = user.lastSeen;
      }

      _users = uniqueUsers.values.toList();
      _sortUsers();
      
      for (var user in _users) {
        if (user.unreadCount > 0) {
          _unreadCounts[user.id] = user.unreadCount;
        }
      }
    } catch (e) {
      _error = 'Failed to load users: $e';
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> fetchContactsAndMatch() async {
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      // 1. Get numbers from device (already cleaned once by service)
      final List<String> deviceNumbers = await ContactService.getDevicePhoneNumbers();

      if (deviceNumbers.isEmpty) {
        _users = [];
        return;
      }

      // 2. Final normalization before sending to API (as requested)
      final List<String> phoneNumbers = deviceNumbers
          .map((num) => ContactService.cleanNumber(num))
          .where((num) => num.length == 10)
          .toList();

      final List<ChatUser> matchedUsers = await _userRepository.matchContacts(phoneNumbers);

      _users = matchedUsers
          .where((user) => _currentUser == null || user.id != _currentUser!.id)
          .toList();
          
      for (var user in _users) {
        _onlineStatus[user.id] = user.isOnline;
        _lastSeenTimes[user.id] = user.lastSeen;
        if (user.unreadCount > 0) {
          _unreadCounts[user.id] = user.unreadCount;
        }
      }
      _sortUsers();
    } catch (e) {
      _error = e.toString().contains('denied') 
          ? 'Contacts permission denied.' 
          : 'Failed to match contacts: $e';
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // ===========================
  // 💬 MESSAGES
  // ===========================

  void setCurrentChat(String? userId) {
    _currentOpenChatUserId = userId;
    if (userId != null) {
      clearUnreadCount(userId);
      _isPartnerTyping = false;
      _markMessagesAsSeen(userId);
    }
    _safeNotifyListeners();
  }

  void _markMessagesAsSeen(String otherUserId) {
    if (_currentUser == null) return;
    
    bool changed = false;
    for (var i = 0; i < _messages.length; i++) {
      if (!_messages[i].isMe && _messages[i].status != MessageStatus.seen) {
        _messages[i] = _messages[i].copyWith(status: MessageStatus.seen);
        SocketService.instance.updateMessageStatus(
          messageId: _messages[i].id,
          senderId: otherUserId,
          receiverId: _currentUser!.id,
          status: 'seen',
        );
        changed = true;
      }
    }
    if (changed) _safeNotifyListeners();
  }

  void clearUnreadCount(String userId) {
    _unreadCounts[userId] = 0;
    final index = _users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      _users[index] = _users[index].copyWith(unreadCount: 0);
    }
    _safeNotifyListeners();
  }

  Future<void> fetchMessages(String receiverId) async {
    if (_currentUser == null) return;

    setCurrentChat(receiverId);
    _isLoading = true;
    _safeNotifyListeners();

    try {
      _messages = await _chatRepository.getMessages(_currentUser!.id, receiverId);
      _markMessagesAsSeen(receiverId);
    } catch (e) {
      _error = 'Failed to load messages';
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<bool> clearChat(String otherUserId) async {
    _isLoading = true;
    _safeNotifyListeners();
    
    final success = await _chatRepository.clearChat(otherUserId);
    
    if (success) {
      if (otherUserId == _currentOpenChatUserId) {
        _messages = [];
      }
      
      final index = _users.indexWhere((u) => u.id == otherUserId);
      if (index != -1) {
        _users[index] = _users[index].copyWith(
          lastMessage: null,
          lastMessageTime: null,
        );
      }
    }
    
    _isLoading = false;
    _safeNotifyListeners();
    return success;
  }

  Future<bool> clearAllChats() async {
    _isLoading = true;
    _safeNotifyListeners();
    
    final success = await _chatRepository.clearAllChats();
    
    if (success) {
      _messages = [];
      _unreadCounts = {};
      
      _users = _users.map((user) => user.copyWith(
        lastMessage: null,
        lastMessageTime: null,
        unreadCount: 0,
      )).toList();
    }
    
    _isLoading = false;
    _safeNotifyListeners();
    return success;
  }

  void _listenForIncomingMessages() {
    // 1. Clear any existing listeners to prevent duplicates
    SocketService.instance.offChatEvents();

    // 2. Handle incoming messages
    SocketService.instance.onReceiveMessage((data) {
      final senderId = data['senderId'] ?? data['sender'];
      final receiverId = data['receiverId'] ?? data['receiver'];

      // Only process if I am the receiver
      if (receiverId == _currentUser?.id) {
        final messageObj = Message.fromJson(data, _currentUser?.id ?? '');
        
        // Prevent duplicate insertion in UI
        final alreadyExists = _messages.any((m) => m.id == messageObj.id);
        if (alreadyExists) {
          print('[Socket] ⚠️ Duplicate message received and ignored: ${messageObj.id}');
          return;
        }

        // Update user in chat list (last message, timestamp, unread count)
        _updateUserInList(
          senderId,
          lastMessage: messageObj.type == MessageType.image 
              ? '📷 Image' 
              : (messageObj.type == MessageType.audio ? '🎤 Voice' : messageObj.text),
          lastMessageTime: messageObj.timestamp,
          incrementUnread: senderId != _currentOpenChatUserId,
          name: data['senderName'] ?? data['name'],
          skipNotify: true, 
        );

        // If currently in this chat, add to messages and mark as seen
        if (senderId == _currentOpenChatUserId) {
          _messages.add(messageObj);
          _markMessagesAsSeen(senderId);
        } else {
          // If not in chat, notify server that it was delivered
          SocketService.instance.updateMessageStatus(
            messageId: messageObj.id,
            senderId: senderId,
            receiverId: _currentUser!.id,
            status: 'delivered',
          );
        }
        _safeNotifyListeners();
      }
    });

    // 3. Handle typing status
    SocketService.instance.onTypingStatus(
      onTyping: (data) {
        if (data['senderId'] == _currentOpenChatUserId) {
          _isPartnerTyping = true;
          _safeNotifyListeners();
        }
      },
      onStopTyping: (data) {
        if (data['senderId'] == _currentOpenChatUserId) {
          _isPartnerTyping = false;
          _safeNotifyListeners();
        }
      },
    );

    // 4. Handle user status (Online/Last Seen/Profile Pic)
    SocketService.instance.onUserStatus((data) {
      final userId = data['userId'];
      if (userId != null) {
        _onlineStatus[userId] = data['isOnline'] ?? false;
        if (data['lastSeen'] != null) {
          _lastSeenTimes[userId] = DateTime.tryParse(data['lastSeen'])?.toLocal();
        }
        
        if (data['profilePic'] != null) {
          _updateUserInList(userId, profilePic: data['profilePic'], skipNotify: true);
        }
        
        _safeNotifyListeners();
      }
    });

    // 5. Handle message status updates (Delivered/Seen)
    SocketService.instance.onMessageStatus((data) {
      final messageId = data['messageId'];
      final statusStr = data['status'];
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        MessageStatus status = MessageStatus.sent;
        if (statusStr == 'seen') status = MessageStatus.seen;
        else if (statusStr == 'delivered') status = MessageStatus.delivered;
        
        _messages[index] = _messages[index].copyWith(status: status);
        _safeNotifyListeners();
      }
    });

    // 6. Handle message deletion
    SocketService.instance.onMessageDeleted((data) {
      final messageId = data['messageId'];
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isDeleted: true, 
          text: 'This message was deleted'
        );
        _safeNotifyListeners();
      }
    });
  }

  Future<void> sendMessage(String receiverId, String text, {
    String? imageUrl, 
    String? audioUrl, 
    MessageType type = MessageType.text
  }) async {
    if (_currentUser == null) return;
    if (_isSendingMessage) return;

    _isSendingMessage = true;
    _safeNotifyListeners();

    try {

    final tempId = _uuid.v4();
    final newMessage = Message(
      id: tempId,
      senderId: _currentUser!.id,
      receiverId: receiverId,
      text: text,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      timestamp: DateTime.now().toLocal(),
      isMe: true,
      type: type,
      replyToId: _replyToMessage?.id,
      replyText: _replyToMessage?.text,
      replyType: _replyToMessage?.type,
    );

    _messages.add(newMessage);
    _replyToMessage = null; // Clear reply
    _safeNotifyListeners();

    final responseData = await _chatRepository.sendMessage(
      sender: _currentUser!.id,
      receiver: receiverId,
      message: text,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      type: type.name,
      replyToId: newMessage.replyToId,
      replyText: newMessage.replyText,
      replyType: newMessage.replyType?.name,
    );

    if (responseData != null) {
      // Fix: Backend returns direct message object. Avoid extracting ['message'] if it's the text string.
      final Map<String, dynamic> messageData;
      if (responseData.containsKey('data') && responseData['data'] is Map<String, dynamic>) {
        messageData = responseData['data'];
      } else if (responseData.containsKey('message') && responseData['message'] is Map<String, dynamic>) {
        messageData = responseData['message'];
      } else {
        messageData = responseData;
      }

      final backendMsg = Message.fromJson(messageData, _currentUser!.id);
      
      if (type == MessageType.audio) {
        print('[ChatProvider] 📝 Audio message created: ${backendMsg.id}');
      }
      
      _updateUserInList(
        receiverId,
        lastMessage: type == MessageType.image ? '📷 Image' : (type == MessageType.audio ? '🎤 Voice' : backendMsg.text),
        lastMessageTime: backendMsg.timestamp,
        skipNotify: true,
      );

      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        _messages[index] = backendMsg;
      }
      
      if (type == MessageType.audio) {
        print('[ChatProvider] 📡 Socket emit: Sending voice message to $receiverId');
      }
      SocketService.instance.sendMessage(
        senderId: _currentUser!.id,
        receiverId: receiverId,
        message: text,
        imageUrl: imageUrl,
        audioUrl: audioUrl,
        type: type.name,
        replyToId: newMessage.replyToId,
        replyText: newMessage.replyText,
        replyType: newMessage.replyType?.name,
      );
      _safeNotifyListeners();
    }
    } catch (e) {
      print('[ChatProvider] Error sending message: $e');
    } finally {
      _isSendingMessage = false;
      _safeNotifyListeners();
    }
  }

  Future<void> deleteMessage(String messageId, bool forEveryone) async {
    if (forEveryone) {
      final success = await _chatRepository.deleteMessage(messageId, true);
      if (success) {
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(isDeleted: true, text: 'This message was deleted');
          _safeNotifyListeners();
        }
      }
    } else {
      // Delete for me (local only as per requirements)
      _messages.removeWhere((m) => m.id == messageId);
      _safeNotifyListeners();
    }
  }

  Future<void> sendImageMessage(String receiverId, XFile file) async {
    _isLoading = true;
    _safeNotifyListeners();
    try {
      final uploadResult = await _chatRepository.uploadFile(file.path, 'image');
      if (uploadResult['success']) {
        await sendMessage(receiverId, '📷 Image', imageUrl: uploadResult['url'], type: MessageType.image);
      }
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> sendVoiceMessage(String receiverId, String path) async {
    print('[ChatProvider] 📞 sendVoiceMessage called for receiver: $receiverId');
    
    if (_isLoading) {
      print('[ChatProvider] ⚠️ Cannot send voice message: Provider is already loading/uploading');
      return;
    }

    if (path.isEmpty) {
      print('[ChatProvider] ❌ Error: Audio path is empty');
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      print('[ChatProvider] ❌ Error: Audio file does not exist at $path');
      return;
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      print('[ChatProvider] ❌ Error: Audio file is empty (0 bytes)');
      return;
    }

    print('[ChatProvider] ✅ Audio file validated. Path: $path, Size: $fileSize bytes');
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      print('[ChatProvider] 🚀 Upload request started for: $path');
      final uploadResult = await _chatRepository.uploadFile(path, 'audio');
      
      if (uploadResult['success'] == true && uploadResult['url'] != null) {
        final audioUrl = uploadResult['url'];
        print('[ChatProvider] ✨ Upload success! URL: $audioUrl');
        
        await sendMessage(
          receiverId, 
          '🎤 Voice', 
          audioUrl: audioUrl, 
          type: MessageType.audio
        );
      } else {
        final errorMsg = uploadResult['message'] ?? 'Failed to upload audio';
        print('[ChatProvider] ❌ Upload failed: $errorMsg');
        _error = errorMsg;
      }
    } catch (e) {
      print('[ChatProvider] ❌ Exception during voice message flow: $e');
      _error = 'Error sending voice message';
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  void setReplyTo(Message? message) {
    _replyToMessage = message;
    _safeNotifyListeners();
  }

  void setUserSearch(String query) {
    _userSearchQuery = query;
    _safeNotifyListeners();
  }

  void setMessageSearch(String query) {
    _messageSearchQuery = query;
    _safeNotifyListeners();
  }

  void sendTypingStatus(String receiverId, bool isTyping) {
    if (_currentUser == null) return;
    SocketService.instance.sendTypingStatus(
      senderId: _currentUser!.id,
      receiverId: receiverId,
      isTyping: isTyping,
    );
  }

  // ===========================
  // 🛠 HELPERS
  // ===========================

  void _sortUsers() {
    _users.sort((a, b) {
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });
  }

  void _updateUserInList(String userId,
      {String? lastMessage, DateTime? lastMessageTime, bool incrementUnread = false, String? name, String? profilePic, bool skipNotify = false}) {
    final index = _users.indexWhere((u) => u.id == userId);
    
    if (index != -1) {
      final user = _users[index];
      final newUnreadCount = incrementUnread ? user.unreadCount + 1 : user.unreadCount;
      
      _users[index] = user.copyWith(
        lastMessage: lastMessage ?? user.lastMessage,
        lastMessageTime: lastMessageTime ?? user.lastMessageTime,
        unreadCount: newUnreadCount,
        profilePic: profilePic ?? user.profilePic,
      );
      
      _unreadCounts[userId] = newUnreadCount;
    } else if (name != null) {
      final newUser = ChatUser(
        id: userId,
        name: name,
        phone: '',
        lastMessage: lastMessage,
        lastMessageTime: lastMessageTime,
        unreadCount: incrementUnread ? 1 : 0,
        profilePic: profilePic,
      );
      _users.add(newUser);
      if (incrementUnread) _unreadCounts[userId] = 1;
    }
    
    _sortUsers();
    if (!skipNotify) _safeNotifyListeners();
  }

  void _safeNotifyListeners() {
    if (!hasListeners) return;
    
    // Use microtask to avoid "setState() or markNeedsBuild() called during build"
    if (WidgetsBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      Future.microtask(() {
        if (hasListeners) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
