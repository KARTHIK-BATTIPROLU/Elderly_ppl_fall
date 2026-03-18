import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

/// Global navigator key so notification taps can navigate outside widget tree.
final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    debugPrint('[API] App bootstrapping started.');
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kDebugMode) {
    debugPrint('[API] Firebase initialized.');
  }

  final authService = AuthService();
  final notificationService = NotificationService();

  // Register tap handler before initialize() so getInitialMessage() can route.
  notificationService.onNotificationTap = (payload) {
    if (kDebugMode) {
      debugPrint('[NAV] Notification tap received. payload=$payload');
    }

    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  };

  final user = await authService.signInAnonymously();
  if (kDebugMode) {
    debugPrint('[API] Authenticated UID: ${user?.uid}');
  }

  await notificationService.initialize();
  if (kDebugMode) {
    debugPrint('[FCM] Notification service initialized from main().');
  }
  notificationService.listenForTokenRefresh(authService);

  try {
    final token = await notificationService.getToken();
    if (token != null && token.isNotEmpty) {
      await authService.updateDeviceToken(token);
      if (kDebugMode) {
        debugPrint('[FCM] Device token synced to Firestore.');
      }
    } else {
      if (kDebugMode) {
        debugPrint('[ERROR] FCM token is null/empty; push notifications may fail.');
      }
    }
    if (kDebugMode) {
      debugPrint('[FCM] FCM TOKEN: $token');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[ERROR] FCM init skipped: $e');
    }
  }

  runApp(FallPreventionApp(navigatorKey: _navigatorKey));
}

class FallPreventionApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const FallPreventionApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elder Fall Prevention',
      navigatorKey: navigatorKey,
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
