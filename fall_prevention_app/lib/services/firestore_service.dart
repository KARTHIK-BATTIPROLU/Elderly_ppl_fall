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
    required int risk,
  }) async {
    final timestamp = FieldValue.serverTimestamp();
    final sensorMap = sensorData.toJson();

    await _db.collection(_predictions).add({
      'sensor_data': sensorMap,
      'risk': risk,
      'timestamp': timestamp,
    });

    await _db.collection(_sensorReadings).add({
      ...sensorMap,
      'timestamp': timestamp,
    });
  }

  // ── Save alert record ──
  Future<void> saveAlert({
    required SensorData sensorData,
    required int risk,
    required bool emailSent,
  }) async {
    await _db.collection(_alerts).add({
      'sensor_data': sensorData.toJson(),
      'risk': risk,
      'email_sent': emailSent,
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
