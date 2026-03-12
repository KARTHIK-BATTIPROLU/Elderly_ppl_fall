import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Request notification permissions & retrieve FCM token
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    if (kDebugMode) {
      print('FCM Token: $token');
    }
  } catch (e) {
    if (kDebugMode) {
      print('FCM init skipped: $e');
    }
  }

  runApp(const FallPreventionApp());
}

class FallPreventionApp extends StatelessWidget {
  const FallPreventionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elder Fall Prevention',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
