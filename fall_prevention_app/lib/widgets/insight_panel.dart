import 'dart:math';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

class InsightPanel extends StatelessWidget {
  final SensorData data;
  final bool isHighRisk;

  const InsightPanel({
    super.key,
    required this.data,
    required this.isHighRisk,
  });

  List<_Insight> _generateInsights() {
    final insights = <_Insight>[];

    // Heart rate analysis
    if (data.heartRate > 110) {
      insights.add(_Insight(
        icon: Icons.favorite,
        color: const Color(0xFFFF1744),
        text: 'Critically elevated heart rate (${data.heartRate} BPM)',
      ));
    } else if (data.heartRate > 100) {
      insights.add(_Insight(
        icon: Icons.favorite,
        color: const Color(0xFFFF9100),
        text: 'Elevated heart rate detected (${data.heartRate} BPM)',
      ));
    } else if (data.heartRate < 55) {
      insights.add(_Insight(
        icon: Icons.favorite_border,
        color: const Color(0xFFFF9100),
        text: 'Low heart rate detected (${data.heartRate} BPM)',
      ));
    } else {
      insights.add(_Insight(
        icon: Icons.favorite,
        color: const Color(0xFF00E676),
        text: 'Heart rate within normal range (${data.heartRate} BPM)',
      ));
    }

    // Chest acceleration magnitude
    final chestMag = sqrt(
      data.chestAccX * data.chestAccX +
      data.chestAccY * data.chestAccY +
      data.chestAccZ * data.chestAccZ,
    );
    if (chestMag > 12.0) {
      insights.add(_Insight(
        icon: Icons.flash_on,
        color: const Color(0xFFFF1744),
        text: 'Sudden chest motion detected (mag: ${chestMag.toStringAsFixed(1)})',
      ));
    } else if (chestMag > 10.5) {
      insights.add(_Insight(
        icon: Icons.vibration,
        color: const Color(0xFFFF9100),
        text: 'Above-normal chest acceleration (mag: ${chestMag.toStringAsFixed(1)})',
      ));
    }

    // Wrist acceleration magnitude
    final wristMag = sqrt(
      data.wristAccX * data.wristAccX +
      data.wristAccY * data.wristAccY +
      data.wristAccZ * data.wristAccZ,
    );
    if (wristMag > 12.0) {
      insights.add(_Insight(
        icon: Icons.watch,
        color: const Color(0xFFFF1744),
        text: 'Sudden wrist motion detected (mag: ${wristMag.toStringAsFixed(1)})',
      ));
    }

    // Posture analysis
    if (data.bodyPosture == 0) {
      insights.add(_Insight(
        icon: Icons.airline_seat_flat,
        color: const Color(0xFFFF9100),
        text: 'Posture suggests possible fall position (Lying Down)',
      ));
    } else if (data.bodyPosture == 4) {
      insights.add(_Insight(
        icon: Icons.directions_run,
        color: const Color(0xFFFF9100),
        text: 'Running detected — elevated fall risk for elderly',
      ));
    }

    // Overall risk
    if (isHighRisk) {
      insights.add(_Insight(
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFFF1744),
        text: 'ML model predicts HIGH fall risk — alert sent',
      ));
    }

    return insights;
  }

  @override
  Widget build(BuildContext context) {
    final insights = _generateInsights();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFAB47BC).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insights, color: Color(0xFFAB47BC), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Real-Time Insights',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...insights.map((i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: i.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: i.color.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(i.icon, color: i.color, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      i.text,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[300],
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

class _Insight {
  final IconData icon;
  final Color color;
  final String text;

  _Insight({required this.icon, required this.color, required this.text});
}
