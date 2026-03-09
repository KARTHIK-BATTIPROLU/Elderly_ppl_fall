import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class HeartRateChart extends StatelessWidget {
  final List<int> heartRates;

  const HeartRateChart({super.key, required this.heartRates});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.red[400], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Heart Rate Trend',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: heartRates.isEmpty
                  ? const Center(child: Text('No data yet'))
                  : LineChart(_buildChart()),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildChart() {
    final spots = heartRates
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 20,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey[200]!,
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) => Text(
              '${value.toInt()}',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ),
        ),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Colors.red[400],
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(radius: 3, color: Colors.red[400]!),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.red[400]!.withValues(alpha: 0.1),
          ),
        ),
      ],
      minY: 40,
      maxY: 150,
    );
  }
}

class AccelerationChart extends StatelessWidget {
  final List<double> chestX;
  final List<double> chestY;
  final List<double> chestZ;
  final String title;
  final IconData icon;
  final Color iconColor;

  const AccelerationChart({
    super.key,
    required this.chestX,
    required this.chestY,
    required this.chestZ,
    this.title = 'Chest Acceleration',
    this.icon = Icons.speed,
    this.iconColor = const Color(0xFF42A5F5),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildLegend(),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: chestX.isEmpty
                  ? const Center(child: Text('No data yet'))
                  : LineChart(_buildChart()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(Colors.blue, 'X'),
        const SizedBox(width: 16),
        _legendDot(Colors.orange, 'Y'),
        const SizedBox(width: 16),
        _legendDot(Colors.teal, 'Z'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  LineChartData _buildChart() {
    List<FlSpot> toSpots(List<double> data) {
      return data
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), e.value))
          .toList();
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 5,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey[200]!,
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(0),
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ),
        ),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: toSpots(chestX),
          isCurved: true,
          color: Colors.blue,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
        LineChartBarData(
          spots: toSpots(chestY),
          isCurved: true,
          color: Colors.orange,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
        LineChartBarData(
          spots: toSpots(chestZ),
          isCurved: true,
          color: Colors.teal,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }
}

class RiskHistoryChart extends StatelessWidget {
  final List<int> risks;

  const RiskHistoryChart({super.key, required this.risks});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.deepPurple[400], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Fall Risk History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: risks.isEmpty
                  ? const Center(child: Text('No data yet'))
                  : BarChart(_buildChart()),
            ),
          ],
        ),
      ),
    );
  }

  BarChartData _buildChart() {
    return BarChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      barGroups: risks.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value.toDouble(),
              color: e.value == 1 ? Colors.red[400] : Colors.green[400],
              width: risks.length > 30 ? 4 : 8,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        );
      }).toList(),
      maxY: 1.2,
    );
  }
}
