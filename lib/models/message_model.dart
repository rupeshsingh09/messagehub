class Message {
  final String senderId;
  final String receiverId;
  final String text;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isMe;

  Message({
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.imageUrl,
    required this.timestamp,
    this.isMe = false,
  });

  factory Message.fromJson(Map<String, dynamic> json, String currentUserId) {
    return Message(
      senderId: json['sender'] ?? '',
      receiverId: json['receiver'] ?? '',
      text: json['message'] ?? '',
      imageUrl: json['imageUrl'],
      timestamp: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      isMe: json['sender'] == currentUserId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender': senderId,
      'receiver': receiverId,
      'message': text,
      'imageUrl': imageUrl,
    };
  }
}
