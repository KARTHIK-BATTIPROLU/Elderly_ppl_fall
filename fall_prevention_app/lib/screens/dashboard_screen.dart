import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';
import '../models/prediction.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';
import '../widgets/sensor_card.dart';
import '../widgets/risk_indicator.dart';
import '../widgets/insight_panel.dart';
import 'analytics_screen.dart';
import 'login_screen.dart';

class _PredictionLogEntry {
  final DateTime timestamp;
  final double riskScore;
  final bool fallDetected;
  final SensorData data;

  _PredictionLogEntry({
    required this.timestamp,
    required this.riskScore,
    required this.fallDetected,
    required this.data,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  static const String _runtimeBackendUrl = String.fromEnvironment('BACKEND_URL');
  ApiService? _api;
  final FirestoreService _firestoreService = FirestoreService();
  Timer? _timer;
  bool _isMonitoring = false;
  String? _error;

  SensorData? _currentData;
  PredictionResult? _currentPrediction;

  // History for analytics
  final List<int> _heartRateHistory = [];
  final List<double> _chestXHistory = [];
  final List<double> _chestYHistory = [];
  final List<double> _chestZHistory = [];
  final List<int> _riskHistory = [];

  // Live prediction log (last 10)
  final List<_PredictionLogEntry> _predictionLog = [];

  late AnimationController _pulseController;

  static const int _maxHistorySize = 50;
  static const int _maxLogSize = 10;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = _runtimeBackendUrl.isNotEmpty
        ? _runtimeBackendUrl
        : (prefs.getString('server_url') ?? 'http://localhost:8000');
    setState(() {
      _api = ApiService(baseUrl: serverUrl);
    });
  }

  void _startMonitoring() {
    setState(() {
      _isMonitoring = true;
      _error = null;
    });
    _pulseController.repeat(reverse: true);
    _fetchAndPredict();
    _timer =
        Timer.periodic(const Duration(seconds: 5), (_) => _fetchAndPredict());
  }

  void _stopMonitoring() {
    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    setState(() => _isMonitoring = false);
  }

  Future<void> _fetchAndPredict() async {
    if (_api == null) return;
    try {
      final data = await _api!.fetchRandomData();
      final prediction = await _api!.predictFallRisk(data);

      // Store in Firestore
      _firestoreService.savePrediction(
        sensorData: data,
        riskScore: prediction.risk,
        fallDetected: prediction.fallDetected,
      );

      if (prediction.isHighRisk) {
        // Push notification dispatched server-side via Firebase Cloud Messaging
        _firestoreService.saveAlert(
          sensorData: data,
          riskScore: prediction.risk,
          fallDetected: prediction.fallDetected,
        );
      }

      setState(() {
        _currentData = data;
        _currentPrediction = prediction;
        _error = null;

        _heartRateHistory.add(data.heartRate);
        _chestXHistory.add(data.chestAccX);
        _chestYHistory.add(data.chestAccY);
        _chestZHistory.add(data.chestAccZ);
        _riskHistory.add(prediction.riskFlag);

        _predictionLog.insert(
          0,
          _PredictionLogEntry(
            timestamp: DateTime.now(),
            riskScore: prediction.risk,
            fallDetected: prediction.fallDetected,
            data: data,
          ),
        );
        if (_predictionLog.length > _maxLogSize) {
          _predictionLog.removeLast();
        }

        if (_heartRateHistory.length > _maxHistorySize) {
          _heartRateHistory.removeAt(0);
          _chestXHistory.removeAt(0);
          _chestYHistory.removeAt(0);
          _chestZHistory.removeAt(0);
          _riskHistory.removeAt(0);
        }
      });
    } catch (e) {
      setState(() => _error = 'Backend server not reachable.');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_isMonitoring) await _fetchAndPredict();
        },
        color: const Color(0xFF00E5FF),
        backgroundColor: const Color(0xFF112240),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // ── SECTION 1: Risk Status ──
            RiskIndicator(
              isHighRisk: _currentPrediction?.isHighRisk ?? false,
              isMonitoring: _isMonitoring,
            ),
            const SizedBox(height: 12),
            _buildControlButton(),

            if (_error != null) ...[
              const SizedBox(height: 10),
              _buildErrorBanner(),
            ],

            if (_isMonitoring && _currentData == null && _error == null) ...[
              const SizedBox(height: 40),
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00E5FF),
                  strokeWidth: 2,
                ),
              ),
            ],

            if (_currentData != null) ...[
              const SizedBox(height: 20),

              // ── SECTION 2: Model Input Values ──
              _sectionHeader('MODEL INPUT FEATURES', Icons.memory),
              const SizedBox(height: 12),

              // Chest Accelerometer group
              _buildSensorGroup(
                title: 'Chest Accelerometer',
                icon: Icons.sensors,
                color: const Color(0xFF42A5F5),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SensorCard(
                          label: 'chest_acc_x',
                          value: _currentData!.chestAccX,
                          unit: 'm/s²',
                          icon: Icons.swap_horiz,
                          accentColor: const Color(0xFF42A5F5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SensorCard(
                          label: 'chest_acc_y',
                          value: _currentData!.chestAccY,
                          unit: 'm/s²',
                          icon: Icons.swap_vert,
                          accentColor: const Color(0xFF42A5F5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SensorCard(
                          label: 'chest_acc_z',
                          value: _currentData!.chestAccZ,
                          unit: 'm/s²',
                          icon: Icons.height,
                          accentColor: const Color(0xFF42A5F5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Wrist Accelerometer group
              _buildSensorGroup(
                title: 'Wrist Accelerometer',
                icon: Icons.watch,
                color: const Color(0xFFFF9800),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SensorCard(
                          label: 'wrist_acc_x',
                          value: _currentData!.wristAccX,
                          unit: 'm/s²',
                          icon: Icons.swap_horiz,
                          accentColor: const Color(0xFFFF9800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SensorCard(
                          label: 'wrist_acc_y',
                          value: _currentData!.wristAccY,
                          unit: 'm/s²',
                          icon: Icons.swap_vert,
                          accentColor: const Color(0xFFFF9800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SensorCard(
                          label: 'wrist_acc_z',
                          value: _currentData!.wristAccZ,
                          unit: 'm/s²',
                          icon: Icons.height,
                          accentColor: const Color(0xFFFF9800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Vital Signs
              _buildSensorGroup(
                title: 'Vital Signs',
                icon: Icons.favorite,
                color: const Color(0xFFEF5350),
                children: [
                  _buildVitalCard(
                    label: 'heart_rate',
                    displayValue: '${_currentData!.heartRate}',
                    unit: 'BPM',
                    icon: Icons.favorite,
                    color: const Color(0xFFEF5350),
                    subtitle: _heartRateStatus(_currentData!.heartRate),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Body Information
              _buildSensorGroup(
                title: 'Body Information',
                icon: Icons.accessibility_new,
                color: const Color(0xFFAB47BC),
                children: [
                  _buildVitalCard(
                    label: 'body_posture',
                    displayValue: _currentData!.postureLabel,
                    unit: 'code: ${_currentData!.bodyPosture}',
                    icon: Icons.accessibility_new,
                    color: const Color(0xFFAB47BC),
                    subtitle: _postureStatus(_currentData!.bodyPosture),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── SECTION 3: Prediction Output ──
              _sectionHeader('PREDICTION OUTPUT', Icons.analytics),
              const SizedBox(height: 12),
              _buildVitalCard(
                label: 'risk_score',
                displayValue: _currentPrediction!.riskPercent,
                unit: 'probability',
                icon: _currentPrediction!.isHighRisk
                    ? Icons.warning_rounded
                    : Icons.check_circle_rounded,
                color: _currentPrediction!.isHighRisk
                    ? const Color(0xFFFF1744)
                    : const Color(0xFF00E676),
                subtitle: _currentPrediction!.label,
              ),
              const SizedBox(height: 20),

              // ── SECTION 4: Insights Panel ──
              _sectionHeader('ANALYSIS & INSIGHTS', Icons.insights),
              const SizedBox(height: 12),
              InsightPanel(
                data: _currentData!,
                isHighRisk: _currentPrediction?.isHighRisk ?? false,
              ),
            ],

            // ── SECTION 4: Live Data Stream ──
            if (_predictionLog.isNotEmpty) ...[
              const SizedBox(height: 20),
              _sectionHeader('LIVE PREDICTION LOG', Icons.list_alt),
              const SizedBox(height: 12),
              _buildPredictionLog(),
            ],
          ],
        ),
      ),
    );
  }

  // ── App Bar ──

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.monitor_heart, color: Color(0xFF00E5FF), size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Fall Prevention Monitor',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 0.3),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isMonitoring) ...[
            const SizedBox(width: 8),
            FadeTransition(
              opacity: _pulseController,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E676),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00E676).withValues(alpha: 0.9),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      backgroundColor: const Color(0xFF0D1B2A),
      foregroundColor: Colors.white,
      elevation: 0,
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
          icon: const Icon(Icons.settings_outlined, size: 22),
          tooltip: 'Settings',
          onPressed: () {
            _stopMonitoring();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      ],
    );
  }

  // ── Helpers ──

  Widget _sectionHeader(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF00E5FF)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64FFDA),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFF1E3A5F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorGroup({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCard({
    required String label,
    required String displayValue,
    required String unit,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      displayValue,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 12,
                        color: color.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _heartRateStatus(int hr) {
    if (hr > 110) return 'Critically elevated';
    if (hr > 100) return 'Elevated';
    if (hr < 55) return 'Below normal';
    return 'Normal range (60-100)';
  }

  String _postureStatus(int posture) {
    switch (posture) {
      case 0:
        return 'Lying — monitor closely';
      case 1:
        return 'Seated — low risk';
      case 2:
        return 'Upright — normal';
      case 3:
        return 'Moving — moderate risk';
      case 4:
        return 'Running — higher fall risk';
      default:
        return 'Unknown posture';
    }
  }

  Widget _buildControlButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
        icon: Icon(
          _isMonitoring ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
          size: 22,
        ),
        label: Text(
          _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isMonitoring
              ? const Color(0xFFB71C1C)
              : const Color(0xFF00C853),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.red[400], size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red[300],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionLog() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: _predictionLog.asMap().entries.map((entry) {
          final log = entry.value;
          final isRisk = log.fallDetected;
          final timeStr =
              '${log.timestamp.hour.toString().padLeft(2, '0')}:'
              '${log.timestamp.minute.toString().padLeft(2, '0')}:'
              '${log.timestamp.second.toString().padLeft(2, '0')}';

          return Container(
            margin: EdgeInsets.only(
              bottom: entry.key < _predictionLog.length - 1 ? 6 : 0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isRisk
                  ? Colors.red.withValues(alpha: 0.08)
                  : Colors.green.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isRisk
                    ? Colors.red.withValues(alpha: 0.2)
                    : Colors.green.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isRisk ? Icons.warning_rounded : Icons.check_circle_rounded,
                  color: isRisk ? Colors.red[400] : Colors.green[400],
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: isRisk ? Colors.red[700] : Colors.green[700],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isRisk ? 'HIGH RISK' : 'SAFE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'R:${(log.riskScore * 100).toStringAsFixed(0)}% HR:${log.data.heartRate}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '#${_predictionLog.length - entry.key}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
