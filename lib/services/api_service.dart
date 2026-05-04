import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/message_model.dart';

class ApiService {
  static String get serverIp {
    if (Platform.isAndroid) {
      return '10.0.2.2';
    } else {
      return '192.168.1.9';
    }
  }

  static String get baseUrl => 'http://$serverIp:5000/api';

  // Generic helper for logging responses (Requirement #4)
  static void _logResponse(http.Response response, String methodName) {
    print('--- [ApiService] $methodName ---');
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
  }

  // Send OTP
  static Future<bool> sendOtp(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      _logResponse(response, 'sendOtp');
      return response.statusCode == 200;
    } catch (e) {
      print('Error sending OTP: $e');
      return false;
    }
  }

  // Verify OTP
  static Future<ChatUser?> verifyOtp(String phone, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'otp': otp}),
      );
      _logResponse(response, 'verifyOtp');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data == null) return null;
        return ChatUser.fromJson(data['user'] ?? data);
      }
      return null;
    } catch (e) {
      print('Error verifying OTP: $e');
      return null;
    }
  }

  // Register User (Requirement #1)
  static Future<ChatUser?> registerUser(String name, String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'phone': phone}),
      );
      _logResponse(response, 'registerUser');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data == null) return null;
        return ChatUser.fromJson(data['user'] ?? data);
      }
      return null;
    } catch (e) {
      print('Error registering user: $e');
      return null;
    }
  }

  // Get all users
  static Future<List<ChatUser>> getUsers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/users'));
      _logResponse(response, 'getUsers');

      if (response.statusCode == 200) {
        final List? data = jsonDecode(response.body);
        if (data == null) return [];
        return data.map((user) => ChatUser.fromJson(user)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  // Send Message
  static Future<bool> sendMessage({
    required String sender,
    required String receiver,
    required String message,
    String? imageUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/messages/send'),
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
        Uri.parse('$baseUrl/messages/$sender/$receiver'),
      );
      _logResponse(response, 'getMessages');

      if (response.statusCode == 200) {
        final List? data = jsonDecode(response.body);
        if (data == null) return [];
        return data.map((msg) => Message.fromJson(msg, sender)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  // Update FCM Token (Requirement #1)
  static Future<bool> updateFcmToken(String userId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/update-fcm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'fcmToken': token}),
      );
      _logResponse(response, 'updateFcmToken');
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating FCM token: $e');
      return false;
    }
  }
}