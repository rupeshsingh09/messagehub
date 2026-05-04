class ChatUser {
  final String id;
  final String name;
  final String phone;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? profilePic;
  final int unreadCount;

  ChatUser({
    required this.id,
    required this.name,
    required this.phone,
    this.lastMessage,
    this.lastMessageTime,
    this.profilePic,
    this.unreadCount = 0,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      lastMessage: json['lastMessage'],
      lastMessageTime: json['lastMessageTime'] != null 
          ? DateTime.tryParse(json['lastMessageTime']) 
          : null,
      profilePic: json['profilePic'],
      unreadCount: json['unreadCount'] ?? 0,
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
    };
  }
}
