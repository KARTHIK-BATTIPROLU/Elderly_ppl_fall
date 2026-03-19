import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
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
    debugPrint('[INIT] App bootstrapping started.');
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kDebugMode) {
    debugPrint('[INIT] Firebase initialized.');
  }

  runApp(const FallPreventionApp());
}

class FallPreventionApp extends StatelessWidget {
  const FallPreventionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elder Fall Prevention',
      navigatorKey: _navigatorKey,
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
      home: const AuthWrapper(),
    );
  }
}

/// AuthWrapper: Checks if user is logged in.
/// - If logged in: Initialize notifications and show Dashboard
/// - If not logged in: Show Login screen
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  late final _notificationService = NotificationService();
  late StreamSubscription<User?> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _setupAuthStateListener();
  }

  void _setupAuthStateListener() {
    _authStateSubscription = _authService.authStateChanges.listen((user) async {
      if (user != null) {
        if (kDebugMode) {
          debugPrint('[AUTH] User logged in: ${user.email} (${user.uid})');
        }
        // Initialize notifications after successful login
        await _initializeNotifications(user);
      } else {
        if (kDebugMode) {
          debugPrint('[AUTH] User logged out.');
        }
      }
    });
  }

  Future<void> _initializeNotifications(User user) async {
    try {
      // Set up notification tap handler
      _notificationService.onNotificationTap = (payload) {
        if (kDebugMode) {
          debugPrint('[NAV] Notification tap received. payload=$payload');
        }
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      };

      // Initialize FCM
      await _notificationService.initialize();
      if (kDebugMode) {
        debugPrint('[FCM] Notification service initialized.');
      }
      
      // Sync token on startup
      await _notificationService.saveTokenToFirestore(user.uid);
      if (kDebugMode) {
        debugPrint('[FCM] Device token synced to Firestore.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ERROR] Notification initialization failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is logged in → show Dashboard
        if (snapshot.hasData) {
          return const DashboardScreen();
        }

        // User is not logged in → show Login screen
        return const LoginScreen();
      },
    );
  }
}

