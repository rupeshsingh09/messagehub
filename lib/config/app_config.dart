import 'dart:io';

class AppConfig {
  // ===========================
  // 🌐 NETWORK CONFIGURATION
  // ===========================

  // Production Backend URL
  static const String _backendUrl = 'https://message-backend-vkn4.onrender.com';

  /// Returns the base URL for the backend API
  static String get baseUrl => _backendUrl;

  /// Returns the URL for the socket connection
  static String get socketUrl => _backendUrl;

  // ===========================
  // 🖼 IMAGE HELPERS
  // ===========================

  static String getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$cleanPath';
  }
}
