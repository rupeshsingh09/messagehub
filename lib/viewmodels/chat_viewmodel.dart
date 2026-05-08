import 'dart:async';
import 'package:flutter/material.dart';
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

class ChatViewModel with ChangeNotifier {
  final UserRepository _userRepository = UserRepository();
  final ChatRepository _chatRepository = ChatRepository();
  final AudioService _audioService = AudioService();
  final _uuid = const Uuid();

  ChatUser? _currentUser;
  List<ChatUser> _users = [];
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;
  bool _isPartnerTyping = false;
  String? _token;
  String? _currentOpenChatUserId;

  String _userSearchQuery = '';
  String _messageSearchQuery = '';
  Message? _replyToMessage;
  Map<String, int> _unreadCounts = {};
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
  Map<String, int> get unreadCounts => _unreadCounts;
  String? get currentOpenChatUserId => _currentOpenChatUserId;
  Map<String, bool> get onlineStatus => _onlineStatus;
  Map<String, DateTime?> get lastSeenTimes => _lastSeenTimes;
  Message? get replyToMessage => _replyToMessage;
  AudioService get audioService => _audioService;

  void setCurrentUser(ChatUser user, String? token) {
    _currentUser = user;
    _token = token;
    StorageService.saveUser(user, token);
    SocketService.instance.connect(user.id);
    _listenForIncomingMessages();
    notifyListeners();
  }

  Future<void> loadUserLocally() async {
    final user = await StorageService.getUser();
    final token = await StorageService.getToken();
    if (user != null) {
      _currentUser = user;
      _token = token;
      SocketService.instance.connect(user.id);
      _listenForIncomingMessages();
      notifyListeners();
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
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    _isLoading = true;
    notifyListeners();
    final success = await _userRepository.deleteAccount();
    if (success) await logout();
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> updateBio(String bio) async {
    if (_currentUser == null) return;
    final success = await _userRepository.updateBio(bio);
    if (success) {
      _currentUser = _currentUser!.copyWith(bio: bio);
      await StorageService.saveUser(_currentUser!, _token);
      notifyListeners();
    }
  }

  Future<void> updateProfilePhoto(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 512);
    if (pickedFile != null) {
      _isLoading = true;
      notifyListeners();
      try {
        final result = await _userRepository.updateProfilePic(pickedFile.path);
        if (result['success'] == true) {
          _currentUser = result['user'] as ChatUser;
          final imageUrl = result['profilePic'] as String;
          await StorageService.saveUser(_currentUser!, _token);
          SocketService.instance.emitProfileUpdate({'userId': _currentUser!.id, 'profilePic': imageUrl});
        } else {
          _error = result['message'] ?? 'Failed to upload photo';
        }
      } catch (e) {
        _error = 'Failed to update profile photo';
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> removeProfilePhoto() async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _userRepository.removeProfilePic();
      if (success) {
        _currentUser = _currentUser?.copyWith(profilePic: '');
        await StorageService.saveUser(_currentUser!, _token);
        SocketService.instance.emitProfileUpdate({'userId': _currentUser!.id, 'profilePic': ''});
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getSavedAccounts() async {
    return await StorageService.getSavedAccounts();
  }

  Future<void> switchAccount(Map<String, dynamic> accountData) async {
    _isLoading = true;
    notifyListeners();
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
      notifyListeners();
    }
  }

  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await _userRepository.sendOtp(phone);
    _isLoading = false;
    if (result['success'] == true) return true;
    _error = result['message'] as String?;
    notifyListeners();
    return false;
  }

  Future<bool> loginWithOtp(String phone, String otp, String firstName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await _userRepository.verifyOtp(phone, otp, firstName);
    _isLoading = false;
    if (result['success'] == true) {
      setCurrentUser(result['user'] as ChatUser, result['token'] as String?);
      return true;
    }
    _error = result['message'] as String?;
    notifyListeners();
    return false;
  }

  Future<void> fetchUsers() async {
    _isLoading = true;
    notifyListeners();
    try {
      final fetchedUsers = await _userRepository.getUsers();
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
        if (user.unreadCount > 0) _unreadCounts[user.id] = user.unreadCount;
      }
    } catch (e) {
      _error = 'Failed to load users: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchContactsAndMatch() async {
    _isLoading = true;
    notifyListeners();
    try {
      final phoneNumbers = await ContactService.getDevicePhoneNumbers();
      if (phoneNumbers.isEmpty) {
        _users = [];
        return;
      }
      final matchedUsers = await _userRepository.matchContacts(phoneNumbers);
      _users = matchedUsers.where((user) => _currentUser == null || user.id != _currentUser!.id).toList();
      for (var user in _users) {
        _onlineStatus[user.id] = user.isOnline;
        _lastSeenTimes[user.id] = user.lastSeen;
        if (user.unreadCount > 0) _unreadCounts[user.id] = user.unreadCount;
      }
      _sortUsers();
    } catch (e) {
      _error = 'Failed to match contacts: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCurrentChat(String? userId) {
    _currentOpenChatUserId = userId;
    if (userId != null) {
      clearUnreadCount(userId);
      _isPartnerTyping = false;
      _markMessagesAsSeen(userId);
    }
    notifyListeners();
  }

  void _markMessagesAsSeen(String otherUserId) {
    if (_currentUser == null) return;
    for (var i = 0; i < _messages.length; i++) {
      if (!_messages[i].isMe && _messages[i].status != MessageStatus.seen) {
        _messages[i] = _messages[i].copyWith(status: MessageStatus.seen);
        SocketService.instance.updateMessageStatus(messageId: _messages[i].id, senderId: otherUserId, receiverId: _currentUser!.id, status: 'seen');
      }
    }
    notifyListeners();
  }

  void clearUnreadCount(String userId) {
    _unreadCounts[userId] = 0;
    final index = _users.indexWhere((u) => u.id == userId);
    if (index != -1) _users[index] = _users[index].copyWith(unreadCount: 0);
    notifyListeners();
  }

  Future<void> fetchMessages(String receiverId) async {
    if (_currentUser == null) return;
    setCurrentChat(receiverId);
    _isLoading = true;
    notifyListeners();
    try {
      _messages = await _chatRepository.getMessages(_currentUser!.id, receiverId);
      _markMessagesAsSeen(receiverId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> clearChat(String otherUserId) async {
    final success = await _chatRepository.clearChat(otherUserId);
    if (success) {
      if (otherUserId == _currentOpenChatUserId) _messages = [];
      final index = _users.indexWhere((u) => u.id == otherUserId);
      if (index != -1) _users[index] = _users[index].copyWith(lastMessage: null, lastMessageTime: null);
    }
    notifyListeners();
    return success;
  }

  Future<bool> clearAllChats() async {
    final success = await _chatRepository.clearAllChats();
    if (success) {
      _messages = [];
      _unreadCounts = {};
      _users = _users.map((user) => user.copyWith(lastMessage: null, lastMessageTime: null, unreadCount: 0)).toList();
    }
    notifyListeners();
    return success;
  }

  void _listenForIncomingMessages() {
    SocketService.instance.offChatEvents();
    SocketService.instance.onReceiveMessage((data) {
      final senderId = data['senderId'] ?? data['sender'];
      final receiverId = data['receiverId'] ?? data['receiver'];
      if (receiverId == _currentUser?.id) {
        final messageObj = Message.fromJson(data, _currentUser?.id ?? '');
        _updateUserInList(senderId, lastMessage: messageObj.type == MessageType.image ? '📷 Image' : (messageObj.type == MessageType.audio ? '🎤 Voice' : messageObj.text), lastMessageTime: messageObj.timestamp, incrementUnread: senderId != _currentOpenChatUserId, name: data['senderName'] ?? data['name']);
        if (senderId == _currentOpenChatUserId) {
          _messages.add(messageObj);
          _markMessagesAsSeen(senderId);
        } else {
          SocketService.instance.updateMessageStatus(messageId: messageObj.id, senderId: senderId, receiverId: _currentUser!.id, status: 'delivered');
        }
        notifyListeners();
      }
    });
    SocketService.instance.onTypingStatus(
      onTyping: (data) { if (data['senderId'] == _currentOpenChatUserId) { _isPartnerTyping = true; notifyListeners(); } },
      onStopTyping: (data) { if (data['senderId'] == _currentOpenChatUserId) { _isPartnerTyping = false; notifyListeners(); } },
    );
    SocketService.instance.onUserStatus((data) {
      final userId = data['userId'];
      if (userId != null) {
        _onlineStatus[userId] = data['isOnline'] ?? false;
        if (data['lastSeen'] != null) _lastSeenTimes[userId] = DateTime.tryParse(data['lastSeen'])?.toLocal();
        if (data['profilePic'] != null) _updateUserInList(userId, profilePic: data['profilePic']);
        notifyListeners();
      }
    });
    SocketService.instance.onMessageStatus((data) {
      final index = _messages.indexWhere((m) => m.id == data['messageId']);
      if (index != -1) {
        MessageStatus status = MessageStatus.sent;
        if (data['status'] == 'seen') status = MessageStatus.seen;
        else if (data['status'] == 'delivered') status = MessageStatus.delivered;
        _messages[index] = _messages[index].copyWith(status: status);
        notifyListeners();
      }
    });
    SocketService.instance.onMessageDeleted((data) {
      final index = _messages.indexWhere((m) => m.id == data['messageId']);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(isDeleted: true, text: 'This message was deleted');
        notifyListeners();
      }
    });
  }

  Future<void> sendMessage(String receiverId, String text, {String? imageUrl, String? audioUrl, MessageType type = MessageType.text}) async {
    if (_currentUser == null) return;
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
    _replyToMessage = null;
    notifyListeners();
    final responseData = await _chatRepository.sendMessage(sender: _currentUser!.id, receiver: receiverId, message: text, imageUrl: imageUrl, audioUrl: audioUrl, type: type.name, replyToId: newMessage.replyToId, replyText: newMessage.replyText, replyType: newMessage.replyType?.name);
    if (responseData != null) {
      final backendMsg = Message.fromJson(responseData, _currentUser!.id);
      _updateUserInList(receiverId, lastMessage: type == MessageType.image ? '📷 Image' : (type == MessageType.audio ? '🎤 Voice' : backendMsg.text), lastMessageTime: backendMsg.timestamp);
      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        _messages[index] = backendMsg;
        notifyListeners();
      }
      SocketService.instance.sendMessage(senderId: _currentUser!.id, receiverId: receiverId, message: text, imageUrl: imageUrl, audioUrl: audioUrl, type: type.name, replyToId: newMessage.replyToId, replyText: newMessage.replyText, replyType: newMessage.replyType?.name);
    }
  }

  Future<void> deleteMessage(String messageId, bool forEveryone) async {
    final success = await _chatRepository.deleteMessage(messageId, forEveryone);
    if (success) {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        if (forEveryone) _messages[index] = _messages[index].copyWith(isDeleted: true, text: 'This message was deleted');
        else _messages.removeAt(index);
        notifyListeners();
      }
    }
  }

  Future<void> sendImageMessage(String receiverId, XFile file) async {
    _isLoading = true;
    notifyListeners();
    try {
      final uploadResult = await _chatRepository.uploadFile(file.path, 'image');
      if (uploadResult['success']) await sendMessage(receiverId, '📷 Image', imageUrl: uploadResult['url'], type: MessageType.image);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendVoiceMessage(String receiverId, String path) async {
    _isLoading = true;
    notifyListeners();
    try {
      final uploadResult = await _chatRepository.uploadFile(path, 'audio');
      if (uploadResult['success']) await sendMessage(receiverId, '🎤 Voice', audioUrl: uploadResult['url'], type: MessageType.audio);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setReplyTo(Message? message) { _replyToMessage = message; notifyListeners(); }
  void setUserSearch(String query) { _userSearchQuery = query; notifyListeners(); }
  void setMessageSearch(String query) { _messageSearchQuery = query; notifyListeners(); }
  void sendTypingStatus(String receiverId, bool isTyping) { if (_currentUser != null) SocketService.instance.sendTypingStatus(senderId: _currentUser!.id, receiverId: receiverId, isTyping: isTyping); }

  void _sortUsers() {
    _users.sort((a, b) {
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });
  }

  void _updateUserInList(String userId, {String? lastMessage, DateTime? lastMessageTime, bool incrementUnread = false, String? name, String? profilePic}) {
    final index = _users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      final user = _users[index];
      final newUnreadCount = incrementUnread ? user.unreadCount + 1 : user.unreadCount;
      _users[index] = user.copyWith(lastMessage: lastMessage ?? user.lastMessage, lastMessageTime: lastMessageTime ?? user.lastMessageTime, unreadCount: newUnreadCount, profilePic: profilePic ?? user.profilePic);
      _unreadCounts[userId] = newUnreadCount;
    } else if (name != null) {
      _users.add(ChatUser(id: userId, name: name, phone: '', lastMessage: lastMessage, lastMessageTime: lastMessageTime, unreadCount: incrementUnread ? 1 : 0, profilePic: profilePic));
      if (incrementUnread) _unreadCounts[userId] = 1;
    }
    _sortUsers();
    notifyListeners();
  }

  @override
  void dispose() { _audioService.dispose(); super.dispose(); }
}
