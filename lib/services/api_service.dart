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
  static void _logRequest(String method, String url, {Map<String, String>? headers, dynamic body}) {
    print('--- [ApiService] REQUEST ---');
    print('Method: $method');
    print('URL: $url');
    if (headers != null) print('Headers: $headers');
    if (body != null) print('Body: $body');
    print('---------------------------');
  }

  static void _logResponse(http.Response response, String methodName) {
    print('--- [ApiService] RESPONSE ($methodName) ---');
    print('URL: ${response.request?.url}');
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
    print('---------------------------');
  }

  /// Extracts error message from backend JSON response
  static String _extractError(http.Response response, String fallback) {
    try {
      if (response.body.isEmpty) return fallback;
      final body = jsonDecode(response.body);
      return body['message'] ?? body['error'] ?? body['msg'] ?? fallback;
    } catch (e) {
      print('[ApiService] Error parsing error response: $e');
      return fallback;
    }
  }

  /// Helper to get headers with Bearer token
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await StorageService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ===========================
  // 🔐 AUTH (OTP BASED)
  // ===========================

  /// POST /api/users/send-otp — sends OTP to phone
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    final url = '$baseUrl/api/users/send-otp';
    final body = jsonEncode({'phone': phone});
    
    try {
      _logRequest('POST', url, body: body);
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 60));

      _logResponse(response, 'sendOtp');

      final success = response.statusCode == 200 || response.statusCode == 201;
      return {
        'success': success,
        'message': success
            ? 'OTP sent successfully'
            : _extractError(response, 'Failed to send OTP (Status: ${response.statusCode})'),
      };
    } catch (e) {
      print('[ApiService] sendOtp Exception: $e');
      String errorMsg = 'Network error. Please check your internet connection.';
      if (e.toString().contains('SocketException')) {
        errorMsg = 'Could not connect to server. Ensure you have internet and the backend is running.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMsg = 'Connection timed out. Render backend might be sleeping, please try again in a moment.';
      }
      return {'success': false, 'message': errorMsg};
    }
  }

  /// POST /api/users/verify-otp — verifies OTP and returns user/token
  static Future<Map<String, dynamic>> verifyOtp(
      String phone, String otp, String firstName) async {
    final url = '$baseUrl/api/users/verify-otp';
    final body = jsonEncode({
      'phone': phone,
      'otp': otp,
      'firstName': firstName,
    });

    try {
      _logRequest('POST', url, body: body);

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 60));

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
      print('[ApiService] verifyOtp Exception: $e');
      return {
        'success': false, 
        'message': 'Network error. Check connection and try again.'
      };
    }
  }

  // ===========================
  // 👥 USERS
  // ===========================

  // Get all users
  static Future<List<dynamic>> getUsers() async {
    final url = '$baseUrl/api/users';
    try {
      final headers = await _getAuthHeaders();
      _logRequest('GET', url, headers: headers);
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

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
    final url = '$baseUrl/api/users/match-contacts';
    final body = jsonEncode({'phoneNumbers': phoneNumbers});
    try {
      final headers = await _getAuthHeaders();
      _logRequest('POST', url, headers: headers, body: body);

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 20));

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
    final url = '$baseUrl/api/messages/send';
    final bodyData = {
      'sender': sender,
      'receiver': receiver,
      'message': message,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'type': type ?? 'text',
      'replyToId': replyToId,
      'replyText': replyText,
      'replyType': replyType,
    };
    try {
      final headers = await _getAuthHeaders();
      _logRequest('POST', url, headers: headers, body: bodyData);

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(bodyData),
      ).timeout(const Duration(seconds: 15));

      _logResponse(response, 'sendMessage');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('[ApiService] Error sending message: $e');
      return null;
    }
  }

  // Delete Message
  static Future<bool> deleteMessage(String messageId, bool forEveryone) async {
    final url = '$baseUrl/api/messages/delete/$messageId';
    final body = jsonEncode({'forEveryone': forEveryone});
    try {
      final headers = await _getAuthHeaders();
      _logRequest('DELETE', url, headers: headers, body: body);

      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 10));

      _logResponse(response, 'deleteMessage');

      return response.statusCode == 200;
    } catch (e) {
      print('[ApiService] Error deleting message: $e');
      return false;
    }
  }

  // Get Messages
  static Future<List<Message>> getMessages(
      String sender,
      String receiver,
      ) async {
    final url = '$baseUrl/api/messages/$sender/$receiver';
    try {
      final headers = await _getAuthHeaders();
      _logRequest('GET', url, headers: headers);

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 60));

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
    final url = '$baseUrl/api/messages/clear/$otherUserId';
    try {
      final headers = await _getAuthHeaders();
      _logRequest('DELETE', url, headers: headers);

      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      _logResponse(response, 'clearChat');

      return response.statusCode == 200;
    } catch (e) {
      print('[ApiService] Error clearing chat: $e');
      return false;
    }
  }

  // Clear All Chats
  static Future<bool> clearAllChats() async {
    final url = '$baseUrl/api/chats/clear';
    try {
      final headers = await _getAuthHeaders();
      _logRequest('DELETE', url, headers: headers);

      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      _logResponse(response, 'clearAllChats');

      return response.statusCode == 200;
    } catch (e) {
      print('[ApiService] Error clearing all chats: $e');
      return false;
    }
  }

  // Delete Account
  static Future<bool> deleteAccount() async {
    final url = '$baseUrl/api/users/delete-account';
    try {
      final headers = await _getAuthHeaders();
      _logRequest('DELETE', url, headers: headers);

      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      _logResponse(response, 'deleteAccount');

      return response.statusCode == 200;
    } catch (e) {
      print('[ApiService] Error deleting account: $e');
      return false;
    }
  }

  // Get User Details (for status/last seen)
  static Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    final url = '$baseUrl/api/users/details/$userId';
    try {
      final headers = await _getAuthHeaders();
      _logRequest('GET', url, headers: headers);

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      _logResponse(response, 'getUserDetails');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('[ApiService] Error getting user details: $e');
      return null;
    }
  }

  // ===========================
  // 🔔 FCM TOKEN
  // ===========================

  static Future<bool> updateFcmToken(String userId, String token) async {
    final url = '$baseUrl/api/users/update-fcm';
    final body = jsonEncode({
      'userId': userId,
      'fcmToken': token,
    });
    try {
      final headers = await _getAuthHeaders();
      _logRequest('POST', url, headers: headers, body: body);

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 10));

      _logResponse(response, 'updateFcmToken');

      return response.statusCode == 200;
    } catch (e) {
      print('[ApiService] Error updating FCM token: $e');
      return false;
    }
  }

  // ===========================
  // 🖼 PROFILE
  // ===========================

  static Future<Map<String, dynamic>> updateProfilePic(String filePath) async {
    final url = '$baseUrl/api/users/profile-photo';
    try {
      final token = await StorageService.getToken();
      var request = http.MultipartRequest('PUT', Uri.parse(url));

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'profilePhoto',
          filePath,
        ),
      );

      _logRequest('PUT (Multipart)', url, headers: request.headers, body: 'File: $filePath');

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
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
      print('[ApiService] Error updating profile pic: $e');
      return {'success': false, 'message': 'Network error during upload'};
    }
  }

  static Future<bool> removeProfilePic() async {
    final url = '$baseUrl/api/users/profile-photo';
    try {
      final headers = await _getAuthHeaders();
      _logRequest('DELETE', url, headers: headers);

      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      _logResponse(response, 'removeProfilePic');

      return response.statusCode == 200;
    } catch (e) {
      print('[ApiService] Error removing profile pic: $e');
      return false;
    }
  }

  static Future<bool> updateBio(String bio) async {
    final url = '$baseUrl/api/users/update-bio';
    final body = jsonEncode({'bio': bio});
    try {
      final headers = await _getAuthHeaders();
      _logRequest('PUT', url, headers: headers, body: body);

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 10));

      _logResponse(response, 'updateBio');

      return response.statusCode == 200;
    } catch (e) {
      print('[ApiService] Error updating bio: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> uploadFile(String filePath, String type) async {
    final url = '$baseUrl/api/messages/upload';
    try {
      final token = await StorageService.getToken();
      var request = http.MultipartRequest('POST', Uri.parse(url));

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

      _logRequest('POST (Multipart)', url, headers: request.headers, body: 'File: $filePath, Type: $type');

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
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
      print('[ApiService] Error uploading $type: $e');
      return {'success': false, 'message': 'Network error during upload'};
    }
  }
}