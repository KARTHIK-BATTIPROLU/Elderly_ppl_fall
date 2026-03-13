import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInAnonymously() async {
    if (_auth.currentUser != null) {
      _ensureUserDocument(_auth.currentUser!);
      return _auth.currentUser;
    }

    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user != null) {
      _ensureUserDocument(user);
    }
    return user;
  }

  /// Sign in with email and password.
  Future<User?> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      // Fire-and-forget: don't block sign-in on Firestore write
      _ensureUserDocument(user);
    }
    return user;
  }

  /// Create a new account with email and password.
  Future<User?> signUpWithEmail(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      // Fire-and-forget: don't block sign-up on Firestore write
      _createUserDocument(user);
    }
    return user;
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Create a Firestore user document for a new user.
  Future<void> _createUserDocument(User user) async {
    String? token;
    try {
      token = await _getFcmToken();
    } catch (e) {
      if (kDebugMode) print('FCM token retrieval failed: $e');
    }

    try {
      await _db.collection('users').doc(user.uid).set({
        'email': user.email,
        'created_at': FieldValue.serverTimestamp(),
        'device_token': token,
      });
    } catch (e) {
      if (kDebugMode) print('Firestore user doc create failed: $e');
    }
  }

  /// Ensure user document exists (for returning users); update token.
  Future<void> _ensureUserDocument(User user) async {
    String? token;
    try {
      token = await _getFcmToken();
    } catch (e) {
      if (kDebugMode) print('FCM token retrieval failed: $e');
    }

    try {
      // set+merge avoids an extra read and works whether doc exists or not
      await _db.collection('users').doc(user.uid).set({
        'device_token': token,
        'last_login': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('Firestore user doc update failed: $e');
    }
  }

  /// Update the device FCM token in Firestore (call on token refresh).
  Future<void> updateDeviceToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'device_token': token,
    }, SetOptions(merge: true));
  }

  Future<String?> _getFcmToken() async {
    if (kIsWeb) {
      const vapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');
      if (vapidKey.isNotEmpty) {
        return FirebaseMessaging.instance.getToken(vapidKey: vapidKey);
      }
    }
    return FirebaseMessaging.instance.getToken();
  }
}
