import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/message_model.dart';

class ApiService {
  // 🔥 Server base URL
  static const String baseUrl = 'http://192.168.1.9:5000';

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
      final response = await http.get(Uri.parse('$baseUrl/api/users'));

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
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/match-contacts'),
        headers: {'Content-Type': 'application/json'},
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
  static Future<bool> sendMessage({
    required String sender,
    required String receiver,
    required String message,
    String? imageUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/messages/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': sender,
          'receiver': receiver,
          'message': message,
          'imageUrl': imageUrl,
        }),
      );

      _logResponse(response, 'sendMessage');

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  // Get Messages
  static Future<List<Message>> getMessages(
      String sender,
      String receiver,
      ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/messages/$sender/$receiver'),
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
  // 🔔 FCM TOKEN
  // ===========================

  static Future<bool> updateFcmToken(String userId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/update-fcm'),
        headers: {'Content-Type': 'application/json'},
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
}