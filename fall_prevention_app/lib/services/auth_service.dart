import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // PUBLIC API
  // ---------------------------------------------------------------------------

  /// Stream of auth changes (User or null)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get current user synchronously
  User? get currentUser => _auth.currentUser;

  /// Sign up with email and password
  /// 1. Create Auth User
  /// 2. Create Firestore Document
  Future<User?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;

      if (user != null) {
        // 2. Create Firestore User Document
        await _createOrUpdateUserDocument(user, isNewUser: true);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) debugPrint("[AuthService] SignUp Error: ${e.code}");
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint("[AuthService] SignUp General Error: $e");
      rethrow;
    }
  }

  /// Log in with email and password
  /// 1. Sign in Auth User
  /// 2. Update Firestore Document (last_login)
  Future<User?> login({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Sign in
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;

      if (user != null) {
        // 2. Update Firestore Document
        await _createOrUpdateUserDocument(user, isNewUser: false);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) debugPrint("[AuthService] Login Error: ${e.code}");
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint("[AuthService] Login General Error: $e");
      rethrow;
    }
  }

  /// Sign out
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // INTERNAL HELPERS
  // ---------------------------------------------------------------------------

  /// Handles creating or updating the user document in Firestore.
  /// 
  /// Logic:
  /// - If new user: Create document with name, email, created_at, last_login
  /// - If existing user: Check if doc exists.
  ///   - If yes: Update last_login
  ///   - If no: Create document (recovery for missing doc)
  Future<void> _createOrUpdateUserDocument(User user, {required bool isNewUser}) async {
    final userRef = _db.collection('users').doc(user.uid);

    try {
      if (isNewUser) {
        // Optimized path for new users
        await userRef.set({
          'name': 'User', // Simple default name
          'email': user.email,
          'created_at': FieldValue.serverTimestamp(),
          'last_login': FieldValue.serverTimestamp(),
        });
      } else {
        // For login: Check if doc exists first
        final doc = await userRef.get();
        if (doc.exists) {
          await userRef.update({
            'last_login': FieldValue.serverTimestamp(),
          });
        } else {
          // Fallback: Create doc if missing logic
          await userRef.set({
            'name': 'User',
            'email': user.email,
            'created_at': FieldValue.serverTimestamp(),
            'last_login': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      // Don't block auth if Firestore fails (e.g. offline), but log it.
      if (kDebugMode) {
        debugPrint("[AuthService] Firestore Error: $e");
      }
    }
  }
}
