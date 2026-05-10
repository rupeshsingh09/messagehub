import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static const String _userKey = 'user_data';
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  static const String _accountsKey = 'saved_accounts';

  // Save user data (also adds to saved accounts)
  static Future<void> saveUser(ChatUser user, String? token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    if (token != null) {
      await prefs.setString(_tokenKey, token);
    }
    await prefs.setString(_userIdKey, user.id);

    // Save to multi-account list
    await _addToSavedAccounts(user, token);
  }

  static Future<void> _addToSavedAccounts(ChatUser user, String? token) async {
    if (token == null) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> accounts = prefs.getStringList(_accountsKey) ?? [];
    
    // Remove if already exists to avoid duplicates (by ID or Phone)
    accounts.removeWhere((acc) {
      final decoded = jsonDecode(acc);
      final storedUser = ChatUser.fromJson(decoded['user']);
      return storedUser.id == user.id || storedUser.phone == user.phone;
    });

    accounts.add(jsonEncode({
      'user': user.toJson(),
      'token': token,
    }));

    await prefs.setStringList(_accountsKey, accounts);
  }

  static Future<List<Map<String, dynamic>>> getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accounts = prefs.getStringList(_accountsKey) ?? [];
    
    final List<Map<String, dynamic>> deduplicated = [];
    final Set<String> seenPhones = {};
    final Set<String> seenIds = {};

    for (var accStr in accounts) {
      final acc = jsonDecode(accStr) as Map<String, dynamic>;
      final user = ChatUser.fromJson(acc['user']);
      
      if (!seenPhones.contains(user.phone) && !seenIds.contains(user.id)) {
        seenPhones.add(user.phone);
        seenIds.add(user.id);
        deduplicated.add(acc);
      }
    }
    
    return deduplicated;
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

  // Clear user data (Logout current session)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }

  // Remove specific account from saved list
  static Future<void> removeAccount(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accounts = prefs.getStringList(_accountsKey) ?? [];
    accounts.removeWhere((acc) {
      final decoded = jsonDecode(acc);
      final user = ChatUser.fromJson(decoded['user']);
      return user.id == userId;
    });
    await prefs.setStringList(_accountsKey, accounts);
  }
}
