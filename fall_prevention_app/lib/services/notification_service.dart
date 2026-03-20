import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/device_utils.dart'; // Import device generation logic

/// Top-level background handler must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('[FCM] Background message received id=${message.messageId}');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  
  /// Callback for notification taps
  void Function(String? payload)? onNotificationTap;

  /// Android channel for high-priority alerts
  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    'fall_risk_alerts',
    'Fall Risk Alerts',
    description: 'High-priority notifications for fall risk detection',
    importance: Importance.max,
    playSound: true,
  );

  /// 1. Initialize FCM & Local Notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    // A. Request Permissions (Web & iOS/Android 13+)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (kDebugMode){
      print('[FCM] Permission status: ${settings.authorizationStatus}');
    }

    // B. Register Background Handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // C. Setup Local Notifications (for foreground alerts)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // For iOS/macOS (Darwin)
    const DarwinInitializationSettings darwinSettings = DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    // Setup local notifications tap
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );

    // Setup background open tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
       onNotificationTap?.call(message.data.toString());
    });

    // D. Create Android Channel (required for Android 8.0+)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // E. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id,
              _androidChannel.name,
              channelDescription: _androidChannel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    // F. Listen for Token Refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      await _onTokenRefresh(newToken);
    });

    _isInitialized = true;
    if (kDebugMode) print('[FCM] initialized successfully');
  }

  /// 2. Get Token (Web requires VAPID key handling, if needed)
  Future<String?> getToken() async {
    try {
      // For web, you might pass vapidKey if configured: getToken(vapidKey: "...")
      return await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) print('[FCM] Error getting token: $e');
      return null;
    }
  }

  /// 3. Save Device Token to Firestore
  /// Structure: users/{uid}/devices/{deviceId}
  Future<void> saveDeviceToken(String uid) async {
    try {
      // A. Get FCM Token
      String? token = await getToken();
      if (token == null) {
        if (kDebugMode) print('[FCM] Failed to get token, retrying once...');
        await Future.delayed(const Duration(seconds: 2));
        token = await getToken();
        if (token == null) return; // Still failed
      }

      // B. Get Persistent Device ID
      String deviceId = await DeviceUtils.getDeviceId();

      // C. Determine Platform
      String platformName = 'unknown';
      if (kIsWeb) {
        platformName = 'web';
      } else {
        if (Platform.isAndroid) platformName = 'android';
        else if (Platform.isIOS) platformName = 'ios';
      }

      // D. Save to Firestore
      final deviceRef = _db
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(deviceId);

      await deviceRef.set({
        'token': token,
        'platform': platformName,
        'updated_at': FieldValue.serverTimestamp(),
        // Use set with merge: true to avoid overwriting created_at if we wanted to keep it
        // But for simplicity, we'll just update everything or use set without merge if we want fresh state always
        'created_at': FieldValue.serverTimestamp(), // This will be overwritten each login, which is fine for "last active" tracking logic roughly
      });

      if (kDebugMode) {
        print('[FCM] Token saved for device: $deviceId under user: $uid');
      }

    } catch (e) {
      if (kDebugMode) print('[FCM] Error saving token to Firestore: $e');
    }
  }

  /// 4. Handle Token Refresh
  Future<void> _onTokenRefresh(String newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        String deviceId = await DeviceUtils.getDeviceId();
        
        await _db
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .doc(deviceId)
            .update({
          'token': newToken,
          'updated_at': FieldValue.serverTimestamp(),
        });
        
        if (kDebugMode) print('[FCM] Refreshed token updated in Firestore');
      } catch (e) {
        if (kDebugMode) print('[FCM] Error updating refreshed token: $e');
      }
    }
  }
}
