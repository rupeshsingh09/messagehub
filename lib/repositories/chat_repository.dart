import '../services/api_service.dart';
import '../models/message_model.dart';

class ChatRepository {
  Future<Map<String, dynamic>?> sendMessage({
    required String sender,
    required String receiver,
    required String message,
    String? imageUrl,
    String? audioUrl,
    String? type,
    String? replyToId,
    String? replyText,
    String? replyType,
  }) {
    return ApiService.sendMessage(
      sender: sender,
      receiver: receiver,
      message: message,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      type: type,
      replyToId: replyToId,
      replyText: replyText,
      replyType: replyType,
    );
  }

  Future<List<Message>> getMessages(String sender, String receiver) {
    return ApiService.getMessages(sender, receiver);
  }

  Future<bool> clearChat(String otherUserId) {
    return ApiService.clearChat(otherUserId);
  }

  Future<bool> clearAllChats() {
    return ApiService.clearAllChats();
  }

  Future<bool> deleteMessage(String messageId, bool forEveryone) {
    return ApiService.deleteMessage(messageId, forEveryone);
  }

  Future<Map<String, dynamic>> uploadFile(String filePath, String type) {
    return ApiService.uploadFile(filePath, type);
  }
}
