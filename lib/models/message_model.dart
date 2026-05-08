enum MessageStatus { sent, delivered, seen }

enum MessageType { text, image, audio }

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String? imageUrl;
  final String? audioUrl;
  final DateTime timestamp;
  final bool isMe;
  final MessageStatus status;
  final MessageType type;
  final bool isDeleted;
  final String? replyToId;
  final String? replyText;
  final MessageType? replyType;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.imageUrl,
    this.audioUrl,
    required this.timestamp,
    this.isMe = false,
    this.status = MessageStatus.sent,
    this.type = MessageType.text,
    this.isDeleted = false,
    this.replyToId,
    this.replyText,
    this.replyType,
  });

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? text,
    String? imageUrl,
    String? audioUrl,
    DateTime? timestamp,
    bool? isMe,
    MessageStatus? status,
    MessageType? type,
    bool? isDeleted,
    String? replyToId,
    String? replyText,
    MessageType? replyType,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      status: status ?? this.status,
      type: type ?? this.type,
      isDeleted: isDeleted ?? this.isDeleted,
      replyToId: replyToId ?? this.replyToId,
      replyText: replyText ?? this.replyText,
      replyType: replyType ?? this.replyType,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json, String currentUserId) {
    String createdAtStr = json['createdAt'] ?? json['timestamp'] ?? '';
    DateTime parsedDate;

    if (createdAtStr.isNotEmpty) {
      if (!createdAtStr.contains('Z') && !createdAtStr.contains('+') && createdAtStr.contains('T')) {
        createdAtStr += 'Z';
      }
      parsedDate = DateTime.parse(createdAtStr).toLocal();
    } else {
      parsedDate = DateTime.now();
    }

    final senderId = json['senderId'] ?? json['sender'] ?? '';
    
    MessageStatus status = MessageStatus.sent;
    if (json['status'] == 'seen') {
      status = MessageStatus.seen;
    } else if (json['status'] == 'delivered') {
      status = MessageStatus.delivered;
    }

    MessageType type = MessageType.text;
    if (json['type'] == 'image') {
      type = MessageType.image;
    } else if (json['type'] == 'audio') {
      type = MessageType.audio;
    }

    MessageType? replyType;
    if (json['replyType'] == 'image') {
      replyType = MessageType.image;
    } else if (json['replyType'] == 'audio') {
      replyType = MessageType.audio;
    } else if (json['replyType'] == 'text') {
      replyType = MessageType.text;
    }

    return Message(
      id: json['_id'] ?? json['id'] ?? '',
      senderId: senderId,
      receiverId: json['receiverId'] ?? json['receiver'] ?? '',
      text: json['message'] ?? json['text'] ?? '',
      imageUrl: json['imageUrl'],
      audioUrl: json['audioUrl'],
      timestamp: parsedDate,
      isMe: senderId == currentUserId,
      status: status,
      type: type,
      isDeleted: json['isDeleted'] ?? false,
      replyToId: json['replyToId'],
      replyText: json['replyText'],
      replyType: replyType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': senderId,
      'receiver': receiverId,
      'message': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'status': status.name,
      'type': type.name,
      'isDeleted': isDeleted,
      'replyToId': replyToId,
      'replyText': replyText,
      'replyType': replyType?.name,
    };
  }
}
