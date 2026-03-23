import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme_data.dart';

/// 通用折线图卡片组件
///
/// 以卡片形式渲染单条实时折线图，提供以下功能：
/// - 顶部标题栏：左侧图表名称，右侧当前数值徽章（主题色）
/// - 折线图区域：基于 [fl_chart] 的 [LineChart]，支持曲线平滑、渐变填充
/// - 动态 X 轴：始终显示最近 60 个时间单位的数据窗口
///
/// 提供两个静态辅助方法 [calculateMinY] 和 [calculateMaxY]，
/// 用于在数据范围较小时确保图表有最小可见高度。
class MonitorChartCard extends StatelessWidget {
  /// 图表标题（左上角文字）
  final String title;

  /// 当前数值文字（右上角徽章，如 "1.02 G"）
  final String value;

  /// 折线图数据点列表（X 轴为时间戳，Y 轴为对应数值）
  final List<FlSpot> spots;

  /// 折线与填充区域的主题颜色
  final Color color;

  /// Y 轴最小值（null 时由图表自动推断）
  final double? minY;

  /// Y 轴最大值（null 时由图表自动推断）
  final double? maxY;

  /// 当前时间戳（用于确定 X 轴右端，左端为 currentTime - 60）
  final double currentTime;

  /// 是否启用曲线平滑（默认 true）
  final bool isCurved;

  /// 曲线平滑度（0.0 = 折线，越大越圆滑，建议 0.1–0.3）
  final double curveSmoothness;

  const MonitorChartCard({
    super.key,
    required this.title,
    required this.value,
    required this.spots,
    required this.color,
    this.minY,
    this.maxY,
    required this.currentTime,
    this.isCurved = true,
    this.curveSmoothness = 0.2,
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
          // 顶部标题栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 左侧：图表标题（次要色，超长时截断）
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
              // 右侧：当前数值徽章（彩色背景 + 加粗文字）
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

          // 折线图区域（占用剩余高度）
          Expanded(
            child: LineChart(
              LineChartData(
                // 隐藏网格线、坐标轴标签、边框，保持简洁风格
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                // X 轴范围：始终显示最近 60 帧的数据窗口
                minX: spots.isNotEmpty ? currentTime - 60 : 0,
                maxX: currentTime,
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: isCurved,
                    curveSmoothness: curveSmoothness,
                    preventCurveOverShooting: true,
                    color: color,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    // 不显示数据点圆点，保持折线简洁
                    dotData: const FlDotData(show: false),
                    // 折线下方渐变填充（低透明度）
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

  // ── 静态轴范围辅助方法 ────────────────────────────────────────────────────

  /// 计算图表 Y 轴的合理最小值
  ///
  /// 当数据序列中最大值与最小值之差小于 [minRange] 时，
  /// 以数据中心为基准向下扩展，确保图表有足够的可见高度。
  /// 数据列表为空时返回 [defaultVal]。
  static double calculateMinY(
    List<FlSpot> spots,
    double minRange, {
    double defaultVal = 0,
  }) {
    if (spots.isEmpty) return defaultVal;
    final min = spots.map((e) => e.y).reduce(math.min);
    final max = spots.map((e) => e.y).reduce(math.max);
    if (max - min < minRange) {
      return min - (minRange - (max - min)) / 2;
    }
    return min - (minRange * 0.1);
  }

  /// 计算图表 Y 轴的合理最大值
  ///
  /// 逻辑与 [calculateMinY] 对称，向上扩展以保证最小可见高度。
  /// 数据列表为空时返回 [defaultVal]。
  static double calculateMaxY(
    List<FlSpot> spots,
    double minRange, {
    double defaultVal = 100,
  }) {
    if (spots.isEmpty) return defaultVal;
    final min = spots.map((e) => e.y).reduce(math.min);
    final max = spots.map((e) => e.y).reduce(math.max);
    if (max - min < minRange) {
      return max + (minRange - (max - min)) / 2;
    }
    return max + (minRange * 0.1);
  }
}
