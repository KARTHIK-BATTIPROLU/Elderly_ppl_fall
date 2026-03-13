class PredictionResult {
  final double risk;
  final bool fallDetected;

  PredictionResult({
    required this.risk,
    required this.fallDetected,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      risk: (json['risk'] as num).toDouble(),
      fallDetected: json['fall_detected'] as bool? ?? false,
    );
  }

  bool get isHighRisk => fallDetected;
  int get riskFlag => fallDetected ? 1 : 0;
  String get label => isHighRisk ? 'HIGH RISK' : 'SAFE';
  String get riskPercent => '${(risk * 100).toStringAsFixed(1)}%';
}
