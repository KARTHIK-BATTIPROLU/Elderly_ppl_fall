import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/sensor_data.dart';
import '../models/prediction.dart';

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl}) {
    if (kDebugMode) {
      debugPrint('Backend URL: $baseUrl');
    }
  }

  Future<bool> checkBackendHealth() async {
    final uri = Uri.parse('$baseUrl/health');
    if (kDebugMode) {
      debugPrint('GET $uri');
    }
    try {
      final response = await http
          .get(
            uri,
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 8));
      if (kDebugMode) {
        debugPrint('Health response: ${response.statusCode} ${response.body}');
      }
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to connect to backend: $e');
      }
      return false;
    }
  }

  Future<SensorData> fetchRandomData() async {
    final uri = Uri.parse('$baseUrl/random-data');
    if (kDebugMode) {
      debugPrint('GET $uri');
    }
    final headers = await _authHeaders();
    final response = await http
        .get(
          uri,
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (kDebugMode) {
      debugPrint('random-data response: ${response.statusCode} ${response.body}');
    }

    if (response.statusCode == 200) {
      return SensorData.fromJson(jsonDecode(response.body));
    }
    if (kDebugMode) {
      debugPrint('Failed to connect to backend');
    }
    throw ApiException('Failed to fetch sensor data: ${response.statusCode}');
  }

  Future<PredictionResult> predictFallRisk(SensorData data) async {
    final uri = Uri.parse('$baseUrl/predict');
    if (kDebugMode) {
      debugPrint('POST $uri');
    }
    final headers = await _authHeaders();

    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode(data.toJson()),
        )
        .timeout(const Duration(seconds: 10));

    if (kDebugMode) {
      debugPrint('predict response: ${response.statusCode} ${response.body}');
    }

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (!decoded.containsKey('risk') && decoded.containsKey('risk_score')) {
        decoded['risk'] = decoded['risk_score'];
      }
      final prediction = PredictionResult.fromJson(decoded);
      if (kDebugMode) {
        debugPrint(
          'Prediction result -> risk=${prediction.risk}, fall_detected=${prediction.fallDetected}',
        );
      }
      return prediction;
    }
    if (kDebugMode) {
      debugPrint('Failed to connect to backend');
    }
    throw ApiException('Prediction failed: ${response.statusCode}');
  }

  Future<Map<String, String>> _authHeaders() async {
    return <String, String>{
      'Content-Type': 'application/json',
    };
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
