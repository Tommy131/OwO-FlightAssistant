import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/monitor_localization_keys.dart';
import '../../providers/monitor_provider.dart';
import 'monitor_chart_card.dart';

/// 实时监控图表区域组件
///
/// 横向或纵向排列三张折线图卡片：
/// - G 力趋势（[MonitorChartCard]，橙色）
/// - 高度趋势（[MonitorChartCard]，主题色，加权滑动平均平滑处理）
/// - 大气压趋势（[MonitorChartCard]，青色）
///
/// 当可用宽度 > 900px 时采用三列并排布局，否则纵向堆叠。
class MonitorCharts extends StatelessWidget {
  /// 监控数据 Provider（读取图表历史数据与当前值）
  final MonitorProvider provider;
  final bool forceSingleColumn;

  const MonitorCharts({
    super.key,
    required this.provider,
    this.forceSingleColumn = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 宽屏（> 900px）时三列并排
        final isThreeColumn = !forceSingleColumn && constraints.maxWidth > 900;

        if (isThreeColumn) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildGForceChart(context)),
              const SizedBox(width: AppThemeData.spacingLarge),
              Expanded(child: _buildAltitudeChart(context)),
              const SizedBox(width: AppThemeData.spacingLarge),
              Expanded(child: _buildPressureChart(context)),
            ],
          );
        }

        // 窄屏时纵向堆叠
        return Column(
          children: [
            _buildGForceChart(context),
            const SizedBox(height: AppThemeData.spacingLarge),
            _buildAltitudeChart(context),
            const SizedBox(height: AppThemeData.spacingLarge),
            _buildPressureChart(context),
          ],
        );
      },
    );
  }

  /// 构建 G 力折线图卡片
  ///
  /// Y 轴固定范围 0–2G，橙色线条。
  Widget _buildGForceChart(BuildContext context) {
    final data = provider.data;
    final chartData = provider.chartData;
    final unit = MonitorLocalizationKeys.unitG.tr(context);
    return MonitorChartCard(
      title: MonitorLocalizationKeys.chartGForceTitle.tr(context),
      value: '${data.gForce?.toStringAsFixed(2) ?? "1.00"} $unit',
      spots: chartData.gForceSpots,
      color: Colors.orangeAccent,
      minY: 0,
      maxY: 2,
      currentTime: chartData.currentTime,
    );
  }

  /// 构建高度趋势折线图卡片
  ///
  /// 数据通过 [_buildFittedAltitudeSpots] 进行加权滑动平均平滑，
  /// Y 轴范围由 [_altitudeAxisMinRange] 动态计算以适应当前高度区间。
  Widget _buildAltitudeChart(BuildContext context) {
    final data = provider.data;
    final chartData = provider.chartData;
    final theme = Theme.of(context);
    final unit = MonitorLocalizationKeys.unitFt.tr(context);

    // 对原始高度数据序列进行平滑处理（减少锯齿）
    final fittedSpots = _buildFittedAltitudeSpots(chartData.altitudeSpots);
    // 根据当前高度动态计算 Y 轴最小可见范围
    final axisMinRange = _altitudeAxisMinRange(data.altitude);

    return MonitorChartCard(
      title: MonitorLocalizationKeys.chartAltitudeTitle.tr(context),
      value: '${data.altitude?.toStringAsFixed(0) ?? "0"} $unit',
      spots: fittedSpots,
      color: theme.colorScheme.primary,
      minY: MonitorChartCard.calculateMinY(
        fittedSpots,
        axisMinRange,
        defaultVal: 0,
      ),
      maxY: MonitorChartCard.calculateMaxY(
        fittedSpots,
        axisMinRange,
        defaultVal: 100,
      ),
      currentTime: chartData.currentTime,
      isCurved: true,
      curveSmoothness: 0.18,
    );
  }

  /// 计算高度图表 Y 轴的最小可见范围
  ///
  /// 基于当前高度的 1.5% 计算动态范围，约束在 [300, 2000] ft 之间，
  /// 防止低空飞行时图表抖动过大，或高空时范围过窄。
  double _altitudeAxisMinRange(double? altitude) {
    final base = (altitude ?? 0).abs() * 0.015;
    return math.max(300, math.min(base, 2000));
  }

  /// 对高度历史数据序列进行加权滑动平均平滑处理
  ///
  /// 使用半径为 2（共 5 个邻近点）的加权窗口，距离越近权重越高（1/distance+1）。
  /// 数据点少于 3 个时直接返回原始序列，避免处理无意义。
  List<FlSpot> _buildFittedAltitudeSpots(List<FlSpot> spots) {
    if (spots.length < 3) return spots;

    const int windowRadius = 2;
    final fitted = <FlSpot>[];

    for (var i = 0; i < spots.length; i++) {
      final start = math.max(0, i - windowRadius);
      final end = math.min(spots.length - 1, i + windowRadius);

      double weightedSum = 0;
      double weightTotal = 0;

      for (var j = start; j <= end; j++) {
        final distance = (i - j).abs();
        // 距离越近权重越高（反距离加权）
        final weight = 1.0 / (distance + 1);
        weightedSum += spots[j].y * weight;
        weightTotal += weight;
      }

      final y = weightedSum / weightTotal;
      fitted.add(FlSpot(spots[i].x, y));
    }

    return fitted;
  }

  /// 构建大气压折线图卡片
  ///
  /// Y 轴固定范围 28–31 inHg（标准大气压附近），青色线条。
  Widget _buildPressureChart(BuildContext context) {
    final data = provider.data;
    final chartData = provider.chartData;
    final unit = MonitorLocalizationKeys.unitInHg.tr(context);
    return MonitorChartCard(
      title: MonitorLocalizationKeys.chartBaroTitle.tr(context),
      value: '${data.baroPressure?.toStringAsFixed(2) ?? "29.92"} $unit',
      spots: chartData.pressureSpots,
      color: Colors.cyanAccent,
      minY: 28,
      maxY: 31,
      currentTime: chartData.currentTime,
    );
  }
}
