import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sensor_data.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Collections ──
  static const String _sensorReadings = 'sensor_readings';
  static const String _predictions = 'predictions';
  static const String _alerts = 'alerts';

  // ── Save sensor reading + prediction ──
  Future<void> savePrediction({
    required SensorData sensorData,
    required double riskScore,
    required bool fallDetected,
  }) async {
    final timestamp = FieldValue.serverTimestamp();
    final sensorMap = sensorData.toJson();

    await _db.collection(_predictions).add({
      'sensor_data': sensorMap,
      'risk': fallDetected ? 1 : 0,
      'risk_score': riskScore,
      'fall_detected': fallDetected,
      'timestamp': timestamp,
    });

    await _db.collection(_sensorReadings).add({
      ...sensorMap,
      'risk_score': riskScore,
      'fall_detected': fallDetected,
      'timestamp': timestamp,
    });
  }

  // ── Save alert record ──
  Future<void> saveAlert({
    required SensorData sensorData,
    required double riskScore,
    required bool fallDetected,
    required bool notificationSent,
    required int notificationSentCount,
    required int notificationTargetCount,
  }) async {
    await _db.collection(_alerts).add({
      'sensor_data': sensorData.toJson(),
      'risk': fallDetected ? 1 : 0,
      'risk_score': riskScore,
      'fall_detected': fallDetected,
      'notification_sent': notificationSent,
      'notification_sent_count': notificationSentCount,
      'notification_target_count': notificationTargetCount,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ── Fetch recent predictions (for analytics) ──
  Future<List<Map<String, dynamic>>> getRecentPredictions({int limit = 60}) async {
    final snapshot = await _db
        .collection(_predictions)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList()
        .reversed
        .toList(); // oldest first for charts
  }

  // ── Stream of predictions (real-time) ──
  Stream<QuerySnapshot> streamPredictions({int limit = 60}) {
    return _db
        .collection(_predictions)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  // ── Fetch alert history ──
  Future<List<Map<String, dynamic>>> getAlertHistory({int limit = 20}) async {
    final snapshot = await _db
        .collection(_alerts)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }
}
