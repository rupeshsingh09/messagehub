import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/message_model.dart';
import 'storage_service.dart';

import '../config/app_config.dart';

class ApiService {
  // 🔥 Server base URL
  static String get baseUrl => AppConfig.baseUrl;

  /// Helper to get full image URL from relative path
  static String getImageUrl(String? path) => AppConfig.getImageUrl(path);

  // 🔍 Debug logger
  static void _logResponse(http.Response response, String methodName) {
    print('--- [ApiService] $methodName ---');
    print('URL: ${response.request?.url}');
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
  }

  /// Extracts error message from backend JSON response
  static String _extractError(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      return body['message'] ?? body['error'] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Helper to get headers with Bearer token
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await StorageService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ===========================
  // 🔐 AUTH (OTP BASED)
  // ===========================

  /// POST /api/users/send-otp — sends OTP to phone
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      _logResponse(response, 'sendOtp');

      final success = response.statusCode == 200 || response.statusCode == 201;
      return {
        'success': success,
        'message': success
            ? 'OTP sent successfully'
            : _extractError(response, 'Failed to send OTP. Please try again.'),
      };
    } catch (e) {
      print('Error sending OTP: $e');
      return {'success': false, 'message': 'Network error. Check connection.'};
    }
  }

  /// POST /api/users/verify-otp — verifies OTP and returns user/token
  static Future<Map<String, dynamic>> verifyOtp(
      String phone, String otp, String firstName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'otp': otp,
          'firstName': firstName,
        }),
      );

      _logResponse(response, 'verifyOtp');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'user': ChatUser.fromJson(data['user'] ?? data),
          'token': data['token'],
          'message': 'Success'
        };
      }

      return {
        'success': false,
        'message': _extractError(response, 'Invalid OTP. Please try again.'),
      };
    } catch (e) {
      print('Error verifying OTP: $e');
      return {'success': false, 'message': 'Network error. Check connection.'};
    }
  }

  // ===========================
  // 👥 USERS
  // ===========================

  // Get all users
  static Future<List<dynamic>> getUsers() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users'),
        headers: headers,
      );

      _logResponse(response, 'getUsers');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> usersData = [];

        if (decoded is Map) {
          usersData = decoded['users'] ?? [];
        } else if (decoded is List) {
          usersData = decoded;
        }

        print('[ApiService] Parsed ${usersData.length} users');
        return usersData;
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[ApiService] Error in getUsers: $e');
      rethrow;
    }
  }

  // Match contacts (WhatsApp-like)
  static Future<List<dynamic>> matchContacts(
      List<String> phoneNumbers) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/match-contacts'),
        headers: headers,
        body: jsonEncode({'phoneNumbers': phoneNumbers}),
      );

      _logResponse(response, 'matchContacts');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> usersData = [];

        if (decoded is Map) {
          usersData = decoded['users'] ?? [];
        } else if (decoded is List) {
          usersData = decoded;
        }

        print('[ApiService] Parsed ${usersData.length} matched contacts');
        return usersData;
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[ApiService] Error in matchContacts: $e');
      rethrow;
    }
  }

  // ===========================
  // 💬 MESSAGES
  // ===========================

  // Send Message
  static Future<Map<String, dynamic>?> sendMessage({
    required String sender,
    required String receiver,
    required String message,
    String? imageUrl,
    String? audioUrl,
    String? type,
    String? replyToId,
    String? replyText,
    String? replyType,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/messages/send'),
        headers: headers,
        body: jsonEncode({
          'sender': sender,
          'receiver': receiver,
          'message': message,
          'imageUrl': imageUrl,
          'audioUrl': audioUrl,
          'type': type ?? 'text',
          'replyToId': replyToId,
          'replyText': replyText,
          'replyType': replyType,
        }),
      );

      _logResponse(response, 'sendMessage');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  // Delete Message
  static Future<bool> deleteMessage(String messageId, bool forEveryone) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/messages/delete/$messageId'),
        headers: headers,
        body: jsonEncode({'forEveryone': forEveryone}),
      );

      _logResponse(response, 'deleteMessage');

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  // Get Messages
  static Future<List<Message>> getMessages(
      String sender,
      String receiver,
      ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/messages/$sender/$receiver'),
        headers: headers,
      );

      _logResponse(response, 'getMessages');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> messagesData = [];

        if (decoded is Map) {
          messagesData = decoded['messages'] ?? decoded['data'] ?? [];
        } else if (decoded is List) {
          messagesData = decoded;
        }

        print('[ApiService] Parsed ${messagesData.length} messages');
        return messagesData.map((msg) => Message.fromJson(msg, sender)).toList();
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[ApiService] Error in getMessages: $e');
      rethrow;
    }
  }

  // ===========================
  // 🧹 CLEANUP & ACCOUNT
  // ===========================

  // Clear Chat History
  static Future<bool> clearChat(String otherUserId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/messages/clear/$otherUserId'),
        headers: headers,
      );

      _logResponse(response, 'clearChat');

      return response.statusCode == 200;
    } catch (e) {
      print('Error clearing chat: $e');
      return false;
    }
  }

  // Clear All Chats
  static Future<bool> clearAllChats() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/chats/clear'),
        headers: headers,
      );

      _logResponse(response, 'clearAllChats');

      return response.statusCode == 200;
    } catch (e) {
      print('Error clearing all chats: $e');
      return false;
    }
  }

  // Delete Account
  static Future<bool> deleteAccount() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/users/delete-account'),
        headers: headers,
      );

      _logResponse(response, 'deleteAccount');

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting account: $e');
      return false;
    }
  }

  // Get User Details (for status/last seen)
  static Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/details/$userId'),
        headers: headers,
      );

      _logResponse(response, 'getUserDetails');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting user details: $e');
      return null;
    }
  }

  // ===========================
  // 🔔 FCM TOKEN
  // ===========================

  static Future<bool> updateFcmToken(String userId, String token) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/update-fcm'),
        headers: headers,
        body: jsonEncode({
          'userId': userId,
          'fcmToken': token,
        }),
      );

      _logResponse(response, 'updateFcmToken');

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating FCM token: $e');
      return false;
    }
  }

  // ===========================
  // 🖼 PROFILE
  // ===========================

  static Future<Map<String, dynamic>> updateProfilePic(String filePath) async {
    try {
      final token = await StorageService.getToken();
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/api/users/profile-photo'),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'profilePhoto',
          filePath,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      _logResponse(response, 'updateProfilePic');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'user': ChatUser.fromJson(data['user']),
          'profilePic': data['user']['profilePic']
        };
      }
      return {
        'success': false,
        'message': _extractError(response, 'Failed to upload photo')
      };
    } catch (e) {
      print('Error updating profile pic: $e');
      return {'success': false, 'message': 'Network error during upload'};
    }
  }

  static Future<bool> removeProfilePic() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/users/profile-photo'),
        headers: headers,
      );

      _logResponse(response, 'removeProfilePic');

      return response.statusCode == 200;
    } catch (e) {
      print('Error removing profile pic: $e');
      return false;
    }
  }

  static Future<bool> updateBio(String bio) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/api/users/update-bio'),
        headers: headers,
        body: jsonEncode({'bio': bio}),
      );

      _logResponse(response, 'updateBio');

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating bio: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> uploadFile(String filePath, String type) async {
    try {
      final token = await StorageService.getToken();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/messages/upload'),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
        ),
      );
      request.fields['type'] = type;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      _logResponse(response, 'uploadFile ($type)');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'url': data['url'],
        };
      }
      return {
        'success': false,
        'message': _extractError(response, 'Failed to upload $type')
      };
    } catch (e) {
      print('Error uploading $type: $e');
      return {'success': false, 'message': 'Network error during upload'};
    }
  }
}