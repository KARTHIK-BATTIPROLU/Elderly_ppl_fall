import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';
import '../widgets/charts.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const String _runtimeBackendUrl = String.fromEnvironment('BACKEND_URL');
  ApiService? _api;
  final FirestoreService _firestoreService = FirestoreService();
  Timer? _timer;
  bool _isLive = false;
  String? _error;
  int _fetchCount = 0;

  // Accumulated history
  final List<int> _heartRates = [];
  final List<double> _chestX = [];
  final List<double> _chestY = [];
  final List<double> _chestZ = [];
  final List<double> _wristX = [];
  final List<double> _wristY = [];
  final List<double> _wristZ = [];
  final List<int> _risks = [];
  final List<int> _postures = [];

  SensorData? _lastData;
  int? _lastRisk;

  static const int _maxPoints = 60;

  @override
  void initState() {
    super.initState();
    _initApi();
  }

  Future<void> _initApi() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = _runtimeBackendUrl.isNotEmpty
        ? _runtimeBackendUrl
        : (prefs.getString('server_url') ?? 'http://192.168.0.4:8001');
    setState(() {
      _api = ApiService(baseUrl: serverUrl);
    });
    await _loadFirestoreHistory();
    await _startLiveFeed();
  }

  Future<void> _loadFirestoreHistory() async {
    try {
      final history = await _firestoreService.getRecentPredictions(limit: _maxPoints);
      if (!mounted || history.isEmpty) return;
      setState(() {
        for (final record in history) {
          final sensor = record['sensor_data'] as Map<String, dynamic>?;
          if (sensor == null) continue;
          _heartRates.add((sensor['heart_rate'] as num?)?.toInt() ?? 0);
          _chestX.add((sensor['chest_acc_x'] as num?)?.toDouble() ?? 0);
          _chestY.add((sensor['chest_acc_y'] as num?)?.toDouble() ?? 0);
          _chestZ.add((sensor['chest_acc_z'] as num?)?.toDouble() ?? 0);
          _wristX.add((sensor['wrist_acc_x'] as num?)?.toDouble() ?? 0);
          _wristY.add((sensor['wrist_acc_y'] as num?)?.toDouble() ?? 0);
          _wristZ.add((sensor['wrist_acc_z'] as num?)?.toDouble() ?? 0);
          _risks.add((record['risk'] as num?)?.toInt() ?? 0);
          _postures.add((sensor['body_posture'] as num?)?.toInt() ?? 0);
        }
        _fetchCount = _heartRates.length;
      });
    } catch (_) {
      // Firestore may not have data yet; continue with live feed only
    }
  }

  Future<void> _startLiveFeed() async {
    if (_api == null) return;
    final reachable = await _api!.checkBackendHealth();
    if (!reachable) {
      if (kDebugMode) {
        debugPrint('Failed to connect to backend');
      }
      setState(() {
        _error = 'Backend server not reachable.';
        _isLive = false;
      });
      return;
    }

    setState(() {
      _isLive = true;
      _error = null;
    });
    _fetchCycle();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchCycle());
  }

  void _stopLiveFeed() {
    _timer?.cancel();
    setState(() => _isLive = false);
  }

  Future<void> _fetchCycle() async {
    if (_api == null) return;
    try {
      final data = await _api!.fetchRandomData();
      final prediction = await _api!.predictFallRisk(data);

      if (!mounted) return;
      setState(() {
        _error = null;
        _fetchCount++;
        _lastData = data;
        _lastRisk = prediction.riskFlag;

        _heartRates.add(data.heartRate);
        _chestX.add(data.chestAccX);
        _chestY.add(data.chestAccY);
        _chestZ.add(data.chestAccZ);
        _wristX.add(data.wristAccX);
        _wristY.add(data.wristAccY);
        _wristZ.add(data.wristAccZ);
        _risks.add(prediction.riskFlag);
        _postures.add(data.bodyPosture);

        // Trim
        if (_heartRates.length > _maxPoints) {
          _heartRates.removeAt(0);
          _chestX.removeAt(0);
          _chestY.removeAt(0);
          _chestZ.removeAt(0);
          _wristX.removeAt(0);
          _wristY.removeAt(0);
          _wristZ.removeAt(0);
          _risks.removeAt(0);
          _postures.removeAt(0);
        }
      });
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint('Failed to connect to backend: $e');
      }
      setState(() => _error = 'Backend server not reachable.');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalReadings = _risks.length;
    final highRiskCount = _risks.where((r) => r == 1).length;
    final safeCount = totalReadings - highRiskCount;
    final avgHeartRate = _heartRates.isEmpty
        ? 0
        : (_heartRates.reduce((a, b) => a + b) / _heartRates.length).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Live Analytics',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_isLive) ...[
              const SizedBox(width: 10),
              _pulseDot(),
              const SizedBox(width: 6),
              Text(
                '#$_fetchCount',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isLive ? Icons.pause_circle : Icons.play_circle),
            tooltip: _isLive ? 'Pause' : 'Resume',
            onPressed: _isLive ? _stopLiveFeed : _startLiveFeed,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Error
          if (_error != null) ...[
            _buildErrorBanner(),
            const SizedBox(height: 12),
          ],

          // Live status bar
          _buildLiveStatusBar(),
          const SizedBox(height: 16),

          // Summary stats
          Row(
            children: [
              Expanded(
                child: _statCard(
                    'Readings', '$totalReadings', Icons.data_usage, Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                    'Avg HR', '$avgHeartRate', Icons.favorite, Colors.red),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                    'Alerts', '$highRiskCount', Icons.warning_rounded, Colors.orange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _statCard('Safe', '$safeCount', Icons.shield, Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Latest model input snapshot
          if (_lastData != null) ...[
            _sectionHeader('LATEST MODEL INPUT', Icons.memory),
            const SizedBox(height: 10),
            _buildLatestInputCard(),
            const SizedBox(height: 20),
          ],

          // Heart Rate Chart
          _sectionHeader('HEART RATE TREND', Icons.favorite),
          const SizedBox(height: 10),
          HeartRateChart(heartRates: _heartRates),
          const SizedBox(height: 20),

          // Chest Acceleration Chart
          _sectionHeader('CHEST ACCELERATION', Icons.speed),
          const SizedBox(height: 10),
          AccelerationChart(
            chestX: _chestX,
            chestY: _chestY,
            chestZ: _chestZ,
          ),
          const SizedBox(height: 20),

          // Wrist Acceleration Chart
          _sectionHeader('WRIST ACCELERATION', Icons.watch),
          const SizedBox(height: 10),
          AccelerationChart(
            chestX: _wristX,
            chestY: _wristY,
            chestZ: _wristZ,
            title: 'Wrist Acceleration',
            icon: Icons.watch,
            iconColor: Colors.orange,
          ),
          const SizedBox(height: 20),

          // Risk History
          _sectionHeader('FALL RISK HISTORY', Icons.timeline),
          const SizedBox(height: 10),
          RiskHistoryChart(risks: _risks),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Helpers ──

  Widget _pulseDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {},
    );
  }

  Widget _sectionHeader(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: _isLive
              ? [const Color(0xFF0D47A1), const Color(0xFF1976D2)]
              : [Colors.grey[400]!, Colors.grey[500]!],
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isLive ? Icons.sensors : Icons.sensors_off,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLive
                      ? 'Fetching live data every 5 seconds'
                      : 'Live feed paused',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_fetchCount data points collected',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_lastRisk != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _lastRisk == 1 ? Colors.red[600] : Colors.green[600],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _lastRisk == 1 ? 'RISK' : 'SAFE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLatestInputCard() {
    final d = _lastData!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _inputRow('chest_acc_x', d.chestAccX.toStringAsFixed(3),
                'chest_acc_y', d.chestAccY.toStringAsFixed(3)),
            _inputRow('chest_acc_z', d.chestAccZ.toStringAsFixed(3),
                'wrist_acc_x', d.wristAccX.toStringAsFixed(3)),
            _inputRow('wrist_acc_y', d.wristAccY.toStringAsFixed(3),
                'wrist_acc_z', d.wristAccZ.toStringAsFixed(3)),
            _inputRow('heart_rate', '${d.heartRate}', 'body_posture',
                '${d.bodyPosture} (${d.postureLabel})'),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Model Output → ',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        _lastRisk == 1 ? Colors.red[600] : Colors.green[600],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _lastRisk == 1 ? 'HIGH RISK (1)' : 'SAFE (0)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputRow(
      String label1, String val1, String label2, String val2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    label1,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Text(
                  val1,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    label2,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    val2,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.red[700], size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red[900],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
