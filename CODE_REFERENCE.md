# Quick Code Reference - Authentication Changes

## 1. AuthService - Key Methods

```dart
// SIGNUP
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
      unawaited(_createUserDocument(user));
      if (kDebugMode) {
        debugPrint('[AUTH] Sign up successful for ${user.email}');
      }
    }
    return user;
  } on FirebaseAuthException catch (e) {
    if (kDebugMode) debugPrint('[ERROR] Sign up failed: ${e.code}');
    rethrow;
  }
}

// LOGIN
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
      unawaited(_updateLastLogin(user));
      if (kDebugMode) {
        debugPrint('[AUTH] Login successful for ${user.email}');
      }
    }
    return user;
  } on FirebaseAuthException catch (e) {
    if (kDebugMode) debugPrint('[ERROR] Login failed: ${e.code}');
    rethrow;
  }
}

// LOGOUT
Future<void> logout() async {
  try {
    await _auth.signOut();
    if (kDebugMode) debugPrint('[AUTH] User logged out successfully');
  } catch (e) {
    if (kDebugMode) debugPrint('[ERROR] Logout failed: $e');
    rethrow;
  }
}

// UPDATE DEVICE TOKEN (called on login and token refresh)
Future<void> updateDeviceToken(String token) async {
  final user = _auth.currentUser;
  if (user == null) {
    if (kDebugMode) debugPrint('[ERROR] Cannot update device token; no user logged in');
    return;
  }

  try {
    await _db.collection('users').doc(user.uid).set({
      'device_token': token,
      'token_updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (kDebugMode) debugPrint('[FIRESTORE] Device token updated for ${user.uid}');
  } catch (e) {
    if (kDebugMode) debugPrint('[ERROR] Device token update failed: $e');
  }
}
```

---

## 2. Main.dart - AuthWrapper Widget

```dart
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

      // Listen for token refresh
      _notificationService.listenForTokenRefresh(_authService);

      // Get and store initial token
      try {
        final token = await _notificationService.getToken();
        if (token != null && token.isNotEmpty) {
          await _authService.updateDeviceToken(token);
          if (kDebugMode) {
            debugPrint('[FCM] Device token synced to Firestore.');
            debugPrint('[FCM] FCM TOKEN: $token');
          }
        } else {
          if (kDebugMode) {
            debugPrint('[ERROR] FCM token is null/empty; push notifications may fail.');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ERROR] FCM token retrieval skipped: $e');
        }
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
```

---

## 3. LoginScreen - Sign Up & Login Forms

```dart
class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSignUp = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      // Navigation handled by AuthWrapper StreamBuilder
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _getUserFriendlyErrorMessage(e.code);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Login failed. Please try again.';
        });
      }
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      // Navigation handled by AuthWrapper StreamBuilder
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _getUserFriendlyErrorMessage(e.code);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sign up failed. Please try again.';
        });
      }
    }
  }

  String _getUserFriendlyErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'Email is already registered.';
      case 'operation-not-allowed':
        return 'Email/password authentication is not enabled.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication error: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Icon(
                    Icons.health_and_safety_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Elder Fall Prevention',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Error message
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  border: Border.all(color: Colors.red.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Email field
                            TextFormField(
                              controller: _emailCtrl,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!v.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),

                            // Password field
                            TextFormField(
                              controller: _passwordCtrl,
                              decoration: InputDecoration(
                                labelText: _isSignUp ? 'Create Password' : 'Password',
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              obscureText: true,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password is required';
                                }
                                if (v.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 28),

                            // Submit button
                            ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : (_isSignUp ? _handleSignUp : _handleLogin),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1565C0),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isSignUp ? Icons.person_add : Icons.login,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _isSignUp ? 'Create Account' : 'Sign In',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 16),

                            // Toggle mode button
                            TextButton(
                              onPressed: _isLoading ? null : _toggleAuthMode,
                              child: Text(
                                _isSignUp
                                    ? 'Already have an account? Sign In'
                                    : 'Don\'t have an account? Sign Up',
                                style: const TextStyle(
                                  color: Color(0xFF1565C0),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleAuthMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _errorMessage = null;
      _emailCtrl.clear();
      _passwordCtrl.clear();
    });
  }
}
```

---

## 4. DashboardScreen - Logout Button

```dart
// In DashboardScreen._buildAppBar()
actions: [
  IconButton(
    icon: const Icon(Icons.analytics_outlined, size: 22),
    tooltip: 'Analytics',
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
    ),
  ),
  IconButton(
    icon: const Icon(Icons.logout_outlined, size: 22),
    tooltip: 'Logout',
    onPressed: () async {
      _stopMonitoring();           // Stop monitoring loop
      await AuthService().logout(); // Sign out from Firebase
      // Navigation handled by AuthWrapper StreamBuilder
    },
  ),
],
```

---

## 5. Usage Examples

### Example 1: Check if User is Logged In
```dart
final authService = AuthService();
final user = authService.currentUser;

if (user != null) {
  print('User email: ${user.email}');
  print('User UID: ${user.uid}');
} else {
  print('No user is logged in');
}
```

### Example 2: Listen to Auth State Changes
```dart
final authService = AuthService();

authService.authStateChanges.listen((user) {
  if (user != null) {
    print('User logged in: ${user.email}');
  } else {
    print('User logged out');
  }
});
```

### Example 3: Handle Login Errors
```dart
try {
  await _authService.login(
    email: 'user@example.com',
    password: 'password123',
  );
} on FirebaseAuthException catch (e) {
  print('Error code: ${e.code}');
  print('Error message: ${e.message}');
  // Handle specific error codes
  if (e.code == 'wrong-password') {
    print('Password is incorrect');
  }
}
```

### Example 4: Update Device Token
```dart
// Called automatically on login, but can be called manually:
final token = await FirebaseMessaging.instance.getToken();
if (token != null) {
  await authService.updateDeviceToken(token);
}
```

---

## 6. Firebase Rules (Recommended)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can only read/write their own document
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
    
    // Only authenticated users can write to predictions
    match /predictions/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Only authenticated users can write to alerts
    match /alerts/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Only authenticated users can write to sensor readings
    match /sensor_readings/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

---

## 7. Environment Setup Checklist

```
☐ Firebase project created
☐ Email/Password provider enabled in Firebase Console
☐ Firestore initialized
☐ Firebase Messaging (FCM) configured
☐ iOS APNs certificate uploaded (if targeting iOS)
☐ Android credentials configured (if targeting Android)
☐ Web VAPID key generated (if targeting web)
☐ publicusers collection exists
☐ Device token structure verified in Firestore
```
