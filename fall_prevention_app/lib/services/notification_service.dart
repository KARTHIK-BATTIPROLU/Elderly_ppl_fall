import 'dart:convert';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';

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
    importance: Importance.high,
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

    _initialized = true;
    _log('NotificationService initialization complete.');
  }

  /// Get current FCM token.
  Future<String?> getToken() async {
    try {
      _log('Requesting FCM token. isWeb=$kIsWeb');
      if (kIsWeb) {
        const vapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');
        if (vapidKey.isEmpty) {
          _error('Missing FCM_WEB_VAPID_KEY on web; token retrieval may fail.');
        }
        if (vapidKey.isNotEmpty) {
          final webToken = await _messaging.getToken(vapidKey: vapidKey);
          _log('Web FCM token generated: ${webToken != null && webToken.isNotEmpty}');
          return webToken;
        }
      }

      final token = await _messaging.getToken();
      _log('FCM token generated: ${token != null && token.isNotEmpty}');
      return token;
    } catch (e) {
      _error('FCM getToken failed: $e');
      return null;
    }
  }

  /// Listen for token refreshes and update Firestore.
  void listenForTokenRefresh(AuthService authService) {
    _onTokenRefreshSub?.cancel();
    _onTokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      _log('FCM token refreshed; updating backend token store.');
      await authService.updateDeviceToken(newToken);
    });
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
          importance: Importance.high,
          priority: Priority.max,
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
