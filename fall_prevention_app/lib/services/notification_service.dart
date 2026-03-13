import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';

/// Top-level background handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Background message: ${message.messageId}');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Callback invoked when the user taps a notification.
  void Function(String? payload)? onNotificationTap;

  static const _androidChannel = AndroidNotificationChannel(
    'fall_risk_alerts',
    'Fall Risk Alerts',
    description: 'High-priority notifications for fall risk detection',
    importance: Importance.high,
  );

  /// Initialize FCM + local notifications. Call once after Firebase.initializeApp().
  Future<void> initialize() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permissions (iOS/Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (kDebugMode) {
      print('Notification permission: ${settings.authorizationStatus}');
    }

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
        onNotificationTap?.call(response.payload);
      },
    );

    // Create Android notification channel
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);

    // Foreground message listener
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // When user taps a notification that opened the app from background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }
  }

  /// Get current FCM token.
  Future<String?> getToken() async {
    try {
      if (kIsWeb) {
        const vapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');
        if (vapidKey.isNotEmpty) {
          return await _messaging.getToken(vapidKey: vapidKey);
        }
      }
      return await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) print('FCM getToken failed: $e');
      return null;
    }
  }

  /// Listen for token refreshes and update Firestore.
  void listenForTokenRefresh(AuthService authService) {
    _messaging.onTokenRefresh.listen((newToken) {
      authService.updateDeviceToken(newToken);
      if (kDebugMode) print('FCM token refreshed');
    });
  }

  /// Show a foreground notification using flutter_local_notifications.
  void _handleForegroundMessage(RemoteMessage message) {
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
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
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
    if (kDebugMode) {
      print('Notification opened: ${message.data}');
    }
    onNotificationTap?.call(jsonEncode(message.data));
  }
}
