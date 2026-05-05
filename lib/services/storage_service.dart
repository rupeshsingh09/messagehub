import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static const String _userKey = 'user_data';
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  // Save user data
  static Future<void> saveUser(ChatUser user, String? token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    if (token != null) {
      await prefs.setString(_tokenKey, token);
    }
    await prefs.setString(_userIdKey, user.id);
  }

  // Get token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Get userId
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Get user data
  static Future<ChatUser?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userData = prefs.getString(_userKey);
    if (userData != null) {
      return ChatUser.fromJson(jsonDecode(userData));
    }
    return null;
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_tokenKey);
  }

  // Clear user data (Logout)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }
}
