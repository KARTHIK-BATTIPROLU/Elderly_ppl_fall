import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('[FCM] Background message received id=${message.messageId} data=${message.data}');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  bool _initialized = false;

  /// Callback invoked when the user taps a notification.
  void Function(String? payload)? onNotificationTap;

  static const _androidChannel = AndroidNotificationChannel(
    'fall_risk_alerts',
    'Fall Risk Alerts',
    description: 'High-priority notifications for fall risk detection',
    importance: Importance.max,
  );

  /// Initialize FCM + local notifications. Call once after Firebase.initializeApp().
  Future<void> initialize() async {
    if (_initialized) {
      _log('NotificationService already initialized; skipping duplicate init.');
      return;
    }

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _log('Registered background handler.');

    // Request permissions (iOS/Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    _log('Notification permission: ${settings.authorizationStatus}');

    // Initialize local notifications for foreground display
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _log('Local notification tapped payload=${response.payload}');
        onNotificationTap?.call(response.payload);
      },
    );

    // Create Android notification channel
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);
    _log('Android notification channel ensured: ${_androidChannel.id}');

    // Foreground message listener
    _onMessageSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // When user taps a notification that opened the app from background/terminated
    _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _log('App opened from terminated state messageId=${initialMessage.messageId}');
      _handleNotificationOpen(initialMessage);
    }

    // Set up token refresh listener
    _onTokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      _log('FCM token refreshed: $newToken');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        saveTokenToFirestore(user.uid, newToken);
      }
    });

    _initialized = true;
    _log('NotificationService initialization complete.');
  }

  /// Get current FCM token.
  Future<String?> getToken() async {
    try {
      _log('Requesting FCM token. isWeb=$kIsWeb');
      String? token;
      if (kIsWeb) {
        const vapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');
        if (vapidKey.isNotEmpty) {
           token = await _messaging.getToken(vapidKey: vapidKey);
        } else {
           token = await _messaging.getToken();
        }
      } else {
        token = await _messaging.getToken();
      }
      
      _log('FCM token generated: ${token != null && token.isNotEmpty}');
      return token;
    } catch (e) {
      _error('FCM getToken failed: $e');
      return null;
    }
  }

  /// Save FCM token to Firestore under users/{uid}/tokens/{token}
  Future<void> saveTokenToFirestore(String uid, [String? specificToken]) async {
    try {
      final token = specificToken ?? await getToken();
      if (token == null) return;

      final tokenRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('tokens')
          .doc(token);

      await tokenRef.set({
        'token': token,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios'),
      });

      _log('Token saved to Firestore for user: $uid');
    } catch (e) {
      _error('Failed to save token to Firestore: $e');
    }
  }

  /// Remove FCM token from Firestore (e.g. on logout)
  Future<void> removeTokenFromFirestore(String uid) async {
    try {
      final token = await getToken();
      if (token == null) return;

      final tokenRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('tokens')
          .doc(token);

      await tokenRef.delete();
      _log('Token removed from Firestore for user: $uid');
    } catch (e) {
      _error('Failed to remove token from Firestore: $e');
    }
  }

  /// Show a foreground notification using flutter_local_notifications.
  void _handleForegroundMessage(RemoteMessage message) {
    _log(
      'Foreground message received id=${message.messageId} '
      'title=${message.notification?.title} data=${message.data}',
    );

    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Fall Risk Alert',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Handle notification tap (background/terminated).
  void _handleNotificationOpen(RemoteMessage message) {
    _log('Notification opened id=${message.messageId} data=${message.data}');
    onNotificationTap?.call(jsonEncode(message.data));
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedSub?.cancel();
    await _onTokenRefreshSub?.cancel();
    _initialized = false;
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[FCM] $message');
    }
  }

  void _error(String message) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
    }
  }
}
