class ChatUser {
  final String id;
  final String name;
  final String phone;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? profilePic;
  final int unreadCount;
  final bool isOnline;
  final DateTime? lastSeen;
  final String bio;

  ChatUser({
    required this.id,
    required this.name,
    required this.phone,
    this.lastMessage,
    this.lastMessageTime,
    this.profilePic,
    this.unreadCount = 0,
    this.isOnline = false,
    this.lastSeen,
    this.bio = "Hey there! I am using MessageHub",
  });

  ChatUser copyWith({
    String? id,
    String? name,
    String? phone,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? profilePic,
    int? unreadCount,
    bool? isOnline,
    DateTime? lastSeen,
    String? bio,
  }) {
    return ChatUser(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      profilePic: profilePic ?? this.profilePic,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      bio: bio ?? this.bio,
    );
  }

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    String? lastTimeStr = json['lastMessageTime'];
    DateTime? lastTime;
    if (lastTimeStr != null && lastTimeStr.isNotEmpty) {
      if (!lastTimeStr.contains('Z') && !lastTimeStr.contains('+') && lastTimeStr.contains('T')) {
        lastTimeStr += 'Z';
      }
      lastTime = DateTime.tryParse(lastTimeStr)?.toLocal();
    }

    String? lastSeenStr = json['lastSeen'];
    DateTime? lastSeen;
    if (lastSeenStr != null && lastSeenStr.isNotEmpty) {
      if (!lastSeenStr.contains('Z') && !lastSeenStr.contains('+') && lastSeenStr.contains('T')) {
        lastSeenStr += 'Z';
      }
      lastSeen = DateTime.tryParse(lastSeenStr)?.toLocal();
    }

    return ChatUser(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim(),
      phone: json['phone'] ?? '',
      lastMessage: json['lastMessage'],
      lastMessageTime: lastTime,
      profilePic: json['profilePic'],
      unreadCount: json['unreadCount'] ?? 0,
      isOnline: json['isOnline'] ?? false,
      lastSeen: lastSeen,
      bio: json['bio'] ?? "Hey there! I am using MessageHub",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'phone': phone,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'profilePic': profilePic,
      'unreadCount': unreadCount,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'bio': bio,
    };
  }
}
