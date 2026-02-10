import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../apps/models/flight_log.dart';
import '../../../core/theme/app_theme_data.dart';

class AnalysisChart extends StatelessWidget {
  final FlightLog log;

  const AnalysisChart({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    if (log.points.length < 2) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final altSpots = <FlSpot>[];
    final spdSpots = <FlSpot>[];

    for (int i = 0; i < log.points.length; i++) {
      final point = log.points[i];
      final time =
          point.timestamp.difference(log.startTime).inSeconds.toDouble() /
          60; // Minutes
      altSpots.add(FlSpot(time, point.altitude));
      spdSpots.add(FlSpot(time, point.groundSpeed));
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildLegendItem(theme, '高度 (ft)', Colors.blue),
              const SizedBox(width: 16),
              _buildLegendItem(theme, '地速 (kts)', Colors.orange),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5000,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value % 10 == 0) {
                          return Text(
                            '${value.toInt()}m',
                            style: theme.textTheme.bodySmall,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        if (value >= 1000) {
                          return Text(
                            '${(value / 1000).toStringAsFixed(0)}k',
                            style: theme.textTheme.bodySmall,
                          );
                        }
                        return Text(
                          value.toInt().toString(),
                          style: theme.textTheme.bodySmall,
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: altSpots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withValues(alpha: 0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: spdSpots,
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) {
                        final isAlt = s.barIndex == 0;
                        return LineTooltipItem(
                          '${isAlt ? "高度" : "速度"}: ${s.y.toInt()}${isAlt ? " ft" : " kts"}',
                          TextStyle(
                            color: isAlt ? Colors.blue : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    if (log.takeoffData != null)
                      VerticalLine(
                        x:
                            log.takeoffData!.timestamp
                                .difference(log.startTime)
                                .inSeconds
                                .toDouble() /
                            60,
                        color: Colors.blue.withValues(alpha: 0.5),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: VerticalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          labelResolver: (line) => '起飞',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (log.landingData != null)
                      VerticalLine(
                        x:
                            log.landingData!.timestamp
                                .difference(log.startTime)
                                .inSeconds
                                .toDouble() /
                            60,
                        color: Colors.orange.withValues(alpha: 0.5),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: VerticalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          labelResolver: (line) => '接地',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(ThemeData theme, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
