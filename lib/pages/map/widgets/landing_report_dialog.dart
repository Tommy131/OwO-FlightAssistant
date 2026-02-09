import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../apps/models/flight_log/flight_log.dart';

class LandingReportDialog extends StatelessWidget {
  final LandingData data;

  const LandingReportDialog({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部横幅
            _buildHeader(theme),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 评分与主要数据
                    _buildMainStats(theme),
                    const SizedBox(height: 32),

                    // G值与垂直速度图表
                    const Text(
                      '着陆序列图表 (G值 & 垂直速度)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildChart(theme, isDark),
                    const SizedBox(height: 32),

                    // 详细原始数据
                    const Text(
                      '着陆原始数据',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildRawDataGrid(theme),
                  ],
                ),
              ),
            ),

            // 底部按钮
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectanglePlatform.isDesktop
                        ? null
                        : RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                  ),
                  child: const Text('了解'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    Color headerColor;
    IconData icon;

    switch (data.rating) {
      case LandingRating.perfect:
        headerColor = Colors.blue;
        icon = Icons.stars_rounded;
        break;
      case LandingRating.soft:
        headerColor = Colors.green;
        icon = Icons.check_circle_outline_rounded;
        break;
      case LandingRating.acceptable:
        headerColor = Colors.teal;
        icon = Icons.info_outline_rounded;
        break;
      case LandingRating.hard:
        headerColor = Colors.orange;
        icon = Icons.warning_amber_rounded;
        break;
      case LandingRating.fired:
        headerColor = Colors.deepOrange;
        icon = Icons.person_off_rounded;
        break;
      case LandingRating.rip:
        headerColor = Colors.red;
        icon = Icons.dangerous_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 64),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.rating.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  data.rating.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStats(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('落地G值', '${data.gForce.toStringAsFixed(2)}G', theme),
        _buildStatItem(
          '垂直速度',
          '${data.verticalSpeed.toStringAsFixed(0)} fpm',
          theme,
        ),
        _buildStatItem(
          '触地速度',
          '${data.airspeed.toStringAsFixed(1)} kts',
          theme,
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: theme.hintColor, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildChart(ThemeData theme, bool isDark) {
    if (data.touchdownSequence.isEmpty) return const SizedBox();

    final gPoints = data.touchdownSequence.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.gForce);
    }).toList();

    /* final vsPoints = data.touchdownSequence.asMap().entries.map((e) {
      // 垂直速度通常是负值且范围较大，归一化处理或分轴显示
      // 这里简化处理，仅展示G值变化
      return FlSpot(e.key.toDouble(), e.value.gForce);
    }).toList(); */

    return Container(
      height: 200,
      padding: const EdgeInsets.only(right: 16, top: 16),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: gPoints,
              isCurved: true,
              color: theme.primaryColor,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: theme.primaryColor.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawDataGrid(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildDataRow(
            '俯仰角 (Pitch)',
            '${data.pitch.toStringAsFixed(1)}°',
            theme,
          ),
          const Divider(),
          _buildDataRow('坡度 (Roll)', '${data.roll.toStringAsFixed(1)}°', theme),
          const Divider(),
          _buildDataRow(
            '空速 (IAS)',
            '${data.airspeed.toStringAsFixed(1)} kts',
            theme,
          ),
          const Divider(),
          _buildDataRow(
            '采样时间',
            data.touchdownSequence.last.timestamp.toString().split('.').first,
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.hintColor)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// 辅助组件：处理不同平台的圆角
class RoundedRectanglePlatform {
  static bool get isDesktop => false; // 这里可以根据项目实际情况判断
}
