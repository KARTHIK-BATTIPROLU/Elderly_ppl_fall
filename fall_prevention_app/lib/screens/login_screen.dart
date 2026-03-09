import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _senderEmailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _receiverEmailCtrl = TextEditingController();
  final _serverUrlCtrl = TextEditingController(text: 'http://localhost:5000');
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
  }

  Future<void> _loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _senderEmailCtrl.text = prefs.getString('sender_email') ?? '';
      _passwordCtrl.text = prefs.getString('password') ?? '';
      _receiverEmailCtrl.text = prefs.getString('receiver_email') ?? '';
      _serverUrlCtrl.text =
          prefs.getString('server_url') ?? 'http://localhost:5000';
    });
  }

  Future<void> _saveAndNavigate() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sender_email', _senderEmailCtrl.text.trim());
    await prefs.setString('password', _passwordCtrl.text);
    await prefs.setString('receiver_email', _receiverEmailCtrl.text.trim());
    await prefs.setString('server_url', _serverUrlCtrl.text.trim());

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  void dispose() {
    _senderEmailCtrl.dispose();
    _passwordCtrl.dispose();
    _receiverEmailCtrl.dispose();
    _serverUrlCtrl.dispose();
    super.dispose();
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
                  const SizedBox(height: 4),
                  Text(
                    'Configure alert settings to start monitoring',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
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
                            const Text(
                              'Email Alert Configuration',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _serverUrlCtrl,
                              decoration: _inputDecor(
                                'Backend Server URL',
                                Icons.dns_outlined,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Enter server URL'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _senderEmailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecor(
                                'Sender Email',
                                Icons.email_outlined,
                              ),
                              validator: (v) => v == null || !v.contains('@')
                                  ? 'Enter valid email'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              decoration: _inputDecor(
                                'App Password',
                                Icons.lock_outlined,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Enter app password'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _receiverEmailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecor(
                                'Receiver Email (Caregiver)',
                                Icons.people_outline,
                              ),
                              validator: (v) => v == null || !v.contains('@')
                                  ? 'Enter valid email'
                                  : null,
                            ),
                            const SizedBox(height: 28),
                            ElevatedButton(
                              onPressed: _saveAndNavigate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1565C0),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.monitor_heart, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Start Monitoring',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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

  InputDecoration _inputDecor(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
