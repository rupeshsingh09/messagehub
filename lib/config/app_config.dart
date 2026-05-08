import 'dart:io';

class AppConfig {
  // ===========================
  // 🌐 NETWORK CONFIGURATION
  // ===========================

  // ⚠️ CHANGE THIS to your machine's local IP for real device testing
  // You can find this by running 'ipconfig' (Windows) or 'ifconfig' (Mac/Linux)
  static const String _wifiIp = '192.168.1.13'; // Example IP

  // Android Emulator loopback IP
  static const String _emulatorIp = '10.0.2.2';

  // Port your Node.js server is running on
  static const String _port = '5000';

  /// Automatically selects the correct base URL
  /// If you are using a real device, make sure [_wifiIp] is correct.
  static String get baseUrl {
    // In a real production app, you'd use a package like device_info_plus 
    // to detect if it's an emulator. For now, we provide a manual toggle
    // or use a smart default.
    
    // Default to emulator IP for Android if not specified otherwise
    // In many cases, 10.0.2.2 is safer for emulator.
    // For real devices, the user MUST update _wifiIp.
    
    // We can use a simple check: if we are on Android and the IP is default, 
    // we might be on emulator. But it's better to be explicit.
    
    const bool isEmulator = true; // TOGGLE THIS FOR REAL DEVICE
    
    final String ip = isEmulator ? _emulatorIp : _wifiIp;
    return 'http://$ip:$_port';
  }

  static String get socketUrl => baseUrl;

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
