class PredictionResult {
  final double risk;
  final bool fallDetected;
  final bool notificationAttempted;
  final int notificationSentCount;
  final int notificationTargetCount;

  PredictionResult({
    required this.risk,
    required this.fallDetected,
    this.notificationAttempted = false,
    this.notificationSentCount = 0,
    this.notificationTargetCount = 0,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      risk: (json['risk'] as num).toDouble(),
      fallDetected: json['fall_detected'] as bool? ?? false,
      notificationAttempted: json['notification_attempted'] as bool? ?? false,
      notificationSentCount: json['notification_sent_count'] as int? ?? 0,
      notificationTargetCount: json['notification_target_count'] as int? ?? 0,
    );
  }

  bool get isHighRisk => fallDetected;
  int get riskFlag => fallDetected ? 1 : 0;
  String get label => isHighRisk ? 'HIGH RISK' : 'SAFE';
  String get riskPercent => '${(risk * 100).toStringAsFixed(1)}%';
}
