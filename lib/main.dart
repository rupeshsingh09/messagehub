import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'services/chat_provider.dart';
import 'services/notification_service.dart';
import 'services/theme_provider.dart';

import 'screens/splash_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/chat_list_screen.dart';

// ===========================
// 🔔 BACKGROUND NOTIFICATION HANDLER
// ===========================
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🔔 Background message: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init
  await Firebase.initializeApp();

  // Background notification handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Local notification init
  await NotificationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// ===========================
// 🚀 APP ROOT
// ===========================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'MessageHub',
      debugShowCheckedModeBanner: false,

      theme: ThemeProvider.lightTheme,
      darkTheme: ThemeProvider.darkTheme,
      themeMode: themeProvider.themeMode,

      // Splash screen is the entry point — it reads SharedPreferences
      // and routes to /home or /auth accordingly.
      initialRoute: '/',

      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const SignupScreen(),
        '/home': (context) => const ChatListScreen(),
      },
    );
  }
}