import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_data.dart';
import '../models/prediction.dart';

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<SensorData> fetchRandomData() async {
    final response = await http
        .get(Uri.parse('$baseUrl/random-data'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return SensorData.fromJson(jsonDecode(response.body));
    }
    throw ApiException('Failed to fetch sensor data: ${response.statusCode}');
  }

  Future<PredictionResult> predictFallRisk(SensorData data) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/predict'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data.toJson()),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return PredictionResult.fromJson(jsonDecode(response.body));
    }
    throw ApiException('Prediction failed: ${response.statusCode}');
  }

  Future<bool> sendEmailAlert({
    required String senderEmail,
    required String password,
    required String receiverEmail,
    required SensorData sensorData,
    required int risk,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/send-alert'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'sender_email': senderEmail,
            'password': password,
            'receiver_email': receiverEmail,
            'sensor_data': sensorData.toJson(),
            'risk': risk,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return true;
    }
    throw ApiException('Failed to send alert: ${response.statusCode}');
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
