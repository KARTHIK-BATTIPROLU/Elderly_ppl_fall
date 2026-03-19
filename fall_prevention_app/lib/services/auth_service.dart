import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up with email and password.
  /// Creates a new Firebase Auth account and Firestore user document.
  Future<User?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        // Fire-and-forget: don't block sign-up on Firestore write
        unawaited(_createUserDocument(user));
        unawaited(NotificationService().saveTokenToFirestore(user.uid));
        if (kDebugMode) {
          debugPrint('[AUTH] Sign up successful for ${user.email}');
        }
      }
      return user;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) debugPrint('[ERROR] Sign up failed: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('[ERROR] Sign up error: $e');
      rethrow;
    }
  }

  /// Sign in with email and password.
  /// Updates the last_login timestamp in Firestore.
  Future<User?> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        // Fire-and-forget: don't block login on Firestore write
        unawaited(_updateLastLogin(user));
        unawaited(NotificationService().saveTokenToFirestore(user.uid));
        if (kDebugMode) {
          debugPrint('[AUTH] Login successful for ${user.email}');
        }
      }
      return user;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) debugPrint('[ERROR] Login failed: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('[ERROR] Login error: $e');
      rethrow;
    }
  }

  /// Sign out the current user.
  Future<void> logout() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await NotificationService().removeTokenFromFirestore(user.uid);
      }
      await _auth.signOut();
      if (kDebugMode) debugPrint('[AUTH] User logged out successfully');
    } catch (e) {
      if (kDebugMode) debugPrint('[ERROR] Logout failed: $e');
      rethrow;
    }
  }

  /// Create a Firestore user document for a new user.
  Future<void> _createUserDocument(User user) async {
    try {
      await _db.collection('users').doc(user.uid).set({
        'email': user.email,
        'created_at': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        debugPrint('[FIRESTORE] User document created for ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ERROR] Firestore user doc create failed: $e');
      }
    }
  }

  /// Update the last_login timestamp for returning users.
  Future<void> _updateLastLogin(User user) async {
    try {
      await _db.collection('users').doc(user.uid).set({
        'last_login': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (kDebugMode) {
        debugPrint('[FIRESTORE] Last login updated for ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ERROR] Firestore last_login update failed: $e');
      }
    }
  }

  /// Update the device FCM token in Firestore.
  /// Called immediately after login and on each token refresh.
  Future<void> updateDeviceToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) {
        debugPrint('[ERROR] Cannot update device token; no user logged in');
      }
      return;
    }

    try {
      await _db.collection('users').doc(user.uid).set({
        'device_token': token,
        'token_updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (kDebugMode) {
        debugPrint('[FIRESTORE] Device token updated for ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ERROR] Device token update failed: $e');
      }
    }
  }
}
