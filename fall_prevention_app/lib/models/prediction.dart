class PredictionResult {
  final int risk;

  PredictionResult({required this.risk});

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(risk: (json['risk'] as num).toInt());
  }

  bool get isHighRisk => risk == 1;

  String get label => isHighRisk ? 'HIGH RISK' : 'SAFE';
}
