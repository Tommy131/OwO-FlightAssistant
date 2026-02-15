import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/monitor_localization_keys.dart';
import '../../providers/monitor_provider.dart';
import 'monitor_chart_card.dart';

class MonitorCharts extends StatelessWidget {
  final MonitorProvider provider;

  const MonitorCharts({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isThreeColumn = constraints.maxWidth > 900;

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

  Widget _buildAltitudeChart(BuildContext context) {
    final data = provider.data;
    final chartData = provider.chartData;
    final theme = Theme.of(context);
    final unit = MonitorLocalizationKeys.unitFt.tr(context);
    return MonitorChartCard(
      title: MonitorLocalizationKeys.chartAltitudeTitle.tr(context),
      value: '${data.altitude?.toStringAsFixed(0) ?? "0"} $unit',
      spots: chartData.altitudeSpots,
      color: theme.colorScheme.primary,
      minY: MonitorChartCard.calculateMinY(
        chartData.altitudeSpots,
        100,
        defaultVal: 0,
      ),
      maxY: MonitorChartCard.calculateMaxY(
        chartData.altitudeSpots,
        100,
        defaultVal: 100,
      ),
      currentTime: chartData.currentTime,
    );
  }

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
