import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme_data.dart';

class MonitorChartCard extends StatelessWidget {
  final String title;
  final String value;
  final List<FlSpot> spots;
  final Color color;
  final double? minY;
  final double? maxY;
  final double currentTime;

  const MonitorChartCard({
    super.key,
    required this.title,
    required this.value,
    required this.spots,
    required this.color,
    this.minY,
    this.maxY,
    required this.currentTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 300,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusLarge),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: theme.hintColor,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  value,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: spots.isNotEmpty ? currentTime - 60 : 0,
                maxX: currentTime,
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static double calculateMinY(
    List<FlSpot> spots,
    double minRange, {
    double defaultVal = 0,
  }) {
    if (spots.isEmpty) return defaultVal;
    double min = spots.map((e) => e.y).reduce(math.min);
    double max = spots.map((e) => e.y).reduce(math.max);
    if (max - min < minRange) {
      return min - (minRange - (max - min)) / 2;
    }
    return min - (minRange * 0.1);
  }

  static double calculateMaxY(
    List<FlSpot> spots,
    double minRange, {
    double defaultVal = 100,
  }) {
    if (spots.isEmpty) return defaultVal;
    double min = spots.map((e) => e.y).reduce(math.min);
    double max = spots.map((e) => e.y).reduce(math.max);
    if (max - min < minRange) {
      return max + (minRange - (max - min)) / 2;
    }
    return max + (minRange * 0.1);
  }
}
