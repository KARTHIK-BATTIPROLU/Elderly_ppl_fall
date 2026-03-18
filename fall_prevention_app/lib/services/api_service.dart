import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/sensor_data.dart';
import '../models/prediction.dart';

Map<String, dynamic> _decodeJsonMap(String source) {
  return jsonDecode(source) as Map<String, dynamic>;
}

class ApiService {
  final String baseUrl;
  final http.Client _client;

  static const int _maxRetries = 3;
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const Duration _healthTimeout = Duration(seconds: 6);
  static const Duration _predictTimeout = Duration(seconds: 20);

  ApiService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client() {
    if (kDebugMode) {
      debugPrint('[API] Backend URL: $baseUrl');
    }
  }

  Future<bool> checkBackendHealth() async {
    final uri = Uri.parse('$baseUrl/health');

    _log('GET $uri [health-check]');
    try {
      final response = await _requestWithRetry(
        requestLabel: 'GET /health',
        timeout: _healthTimeout,
        makeRequest: () async {
          return _client.get(uri, headers: await _authHeaders());
        },
      );
      _log('Health response: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      _error('Backend unreachable at $uri: $e');
      return false;
    }
  }

  Future<SensorData> fetchRandomData() async {
    final uri = Uri.parse('$baseUrl/random-data');
    _log('GET $uri');
    final headers = await _authHeaders();
    final response = await _requestWithRetry(
      requestLabel: 'GET /random-data',
      timeout: _requestTimeout,
      makeRequest: () => _client.get(uri, headers: headers),
    );

    _log('random-data response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 200) {
      final decoded = await compute(_decodeJsonMap, response.body);
      return SensorData.fromJson(decoded);
    }

    throw ApiException(
      'Failed to fetch sensor data: status=${response.statusCode}, body=${response.body}',
    );
  }

  Future<PredictionResult> predictFallRisk(SensorData data) async {
    final uri = Uri.parse('$baseUrl/predict');
    _log('POST $uri');
    final headers = await _authHeaders();

    final response = await _requestWithRetry(
      requestLabel: 'POST /predict',
      timeout: _predictTimeout,
      maxRetries: 1,
      makeRequest: () => _client.post(
        uri,
        headers: headers,
        body: jsonEncode(data.toJson()),
      ),
    );

    _log('predict response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 200) {
      final decoded = await compute(_decodeJsonMap, response.body);
      if (!decoded.containsKey('risk') && decoded.containsKey('risk_score')) {
        decoded['risk'] = decoded['risk_score'];
      }
      final prediction = PredictionResult.fromJson(decoded);
      _log(
        'Prediction result -> risk=${prediction.risk}, fall_detected=${prediction.fallDetected}',
      );
      return prediction;
    }

    throw ApiException(
      'Prediction failed: status=${response.statusCode}, body=${response.body}',
    );
  }

  Future<http.Response> _requestWithRetry({
    required String requestLabel,
    required Duration timeout,
    required Future<http.Response> Function() makeRequest,
    int? maxRetries,
  }) async {
    final int retries = maxRetries ?? _maxRetries;
    Duration delay = const Duration(milliseconds: 300);
    Object? lastError;

    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        _log('$requestLabel attempt $attempt/$_maxRetries');
        final response = await makeRequest().timeout(timeout);

        if (response.statusCode >= 500 && attempt < retries) {
          _error(
            '$requestLabel server error ${response.statusCode}. Retrying in ${delay.inMilliseconds}ms',
          );
          await Future<void>.delayed(delay);
          delay *= 2;
          continue;
        }

        return response;
      } catch (e) {
        lastError = e;

        if (attempt == retries) {
          break;
        }

        _error(
          '$requestLabel failed on attempt $attempt: $e. Retrying in ${delay.inMilliseconds}ms',
        );
        await Future<void>.delayed(delay);
        delay *= 2;
      }
    }

    throw ApiException(
      '$requestLabel failed after $retries attempts. baseUrl=$baseUrl, error=$lastError',
    );
  }

  Future<Map<String, String>> _authHeaders() async {
    return <String, String>{
      'Content-Type': 'application/json',
    };
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[API] $message');
    }
  }

  void _error(String message) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
