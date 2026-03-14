import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final authService = AuthService();
  final notificationService = NotificationService();

  final user = await authService.signInAnonymously();
  if (kDebugMode) {
    print('Authenticated UID: ${user?.uid}');
  }

  await notificationService.initialize();
  notificationService.listenForTokenRefresh(authService);

  try {
    final token = await notificationService.getToken();
    if (token != null && token.isNotEmpty) {
      await authService.updateDeviceToken(token);
    }
    if (kDebugMode) {
      print('FCM TOKEN: $token');
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
