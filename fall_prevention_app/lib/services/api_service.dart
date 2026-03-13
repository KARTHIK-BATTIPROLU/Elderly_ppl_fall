import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/sensor_data.dart';
import '../models/prediction.dart';

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<SensorData> fetchRandomData() async {
    final headers = await _authHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl/random-data'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return SensorData.fromJson(jsonDecode(response.body));
    }
    throw ApiException('Failed to fetch sensor data: ${response.statusCode}');
  }

  Future<PredictionResult> predictFallRisk(SensorData data) async {
    final headers = await _authHeaders();

    final response = await http
        .post(
          Uri.parse('$baseUrl/predict'),
          headers: headers,
          body: jsonEncode(data.toJson()),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return PredictionResult.fromJson(jsonDecode(response.body));
    }
    throw ApiException('Prediction failed: ${response.statusCode}');
  }

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw ApiException('No authenticated Firebase user available');
    }

    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw ApiException('Failed to obtain Firebase ID token');
    }

    if (kDebugMode) {
      debugPrint('Firebase token: $token');
    }

    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
