import 'package:flutter/material.dart';

class RiskIndicator extends StatelessWidget {
  final bool isHighRisk;
  final bool isMonitoring;

  const RiskIndicator({
    super.key,
    required this.isHighRisk,
    this.isMonitoring = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMonitoring) {
      return _buildIdleState();
    }

    final Color primaryColor =
        isHighRisk ? const Color(0xFFFF1744) : const Color(0xFF00E676);
    final Color bgStart =
        isHighRisk ? const Color(0xFF3E0000) : const Color(0xFF003300);
    final Color bgEnd =
        isHighRisk ? const Color(0xFF1A0000) : const Color(0xFF001A00);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [bgStart, bgEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glowing icon container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(
              isHighRisk ? Icons.warning_rounded : Icons.shield_rounded,
              color: primaryColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isHighRisk ? 'HIGH FALL RISK' : 'SAFE',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isHighRisk
                    ? 'Alert sent to caregiver'
                    : 'All vitals within normal range',
                style: TextStyle(
                  color: primaryColor.withValues(alpha: 0.6),
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdleState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF112240),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.monitor_heart_outlined,
              color: Colors.grey[500],
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NOT MONITORING',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Start monitoring to track risk',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
