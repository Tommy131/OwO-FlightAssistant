import 'package:flutter/material.dart';
import '../../../apps/providers/simulator/simulator_provider.dart';
import '../../../core/theme/app_theme_data.dart';
import 'monitor_chart_card.dart';

class MonitorCharts extends StatelessWidget {
  final SimulatorProvider simProvider;

  const MonitorCharts({super.key, required this.simProvider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isThreeColumn = constraints.maxWidth > 900;

        if (isThreeColumn) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildGForceChart()),
              const SizedBox(width: AppThemeData.spacingLarge),
              Expanded(child: _buildAltitudeChart(theme)),
              const SizedBox(width: AppThemeData.spacingLarge),
              Expanded(child: _buildPressureChart()),
            ],
          );
        } else {
          return Column(
            children: [
              _buildGForceChart(),
              const SizedBox(height: AppThemeData.spacingLarge),
              _buildAltitudeChart(theme),
              const SizedBox(height: AppThemeData.spacingLarge),
              _buildPressureChart(),
            ],
          );
        }
      },
    );
  }

  Widget _buildGForceChart() {
    final data = simProvider.simulatorData;
    return MonitorChartCard(
      title: '重力监控 (G-Force)',
      value: '${data.gForce?.toStringAsFixed(2) ?? "1.00"} G',
      spots: simProvider.gForceSpots,
      color: Colors.orangeAccent,
      minY: 0,
      maxY: 2,
      currentTime: simProvider.chartTime,
    );
  }

  Widget _buildAltitudeChart(ThemeData theme) {
    final data = simProvider.simulatorData;
    return MonitorChartCard(
      title: '高度趋势 (Altitude)',
      value: '${data.altitude?.toStringAsFixed(0) ?? "0"} FT',
      spots: simProvider.altitudeSpots,
      color: theme.colorScheme.primary,
      minY: MonitorChartCard.calculateMinY(
        simProvider.altitudeSpots,
        100,
        defaultVal: 0,
      ),
      maxY: MonitorChartCard.calculateMaxY(
        simProvider.altitudeSpots,
        100,
        defaultVal: 100,
      ),
      currentTime: simProvider.chartTime,
    );
  }

  Widget _buildPressureChart() {
    final data = simProvider.simulatorData;
    return MonitorChartCard(
      title: '大气压强 (Baro)',
      value: '${data.baroPressure?.toStringAsFixed(2) ?? "29.92"} inHg',
      spots: simProvider.pressureSpots,
      color: Colors.cyanAccent,
      minY: 28,
      maxY: 31,
      currentTime: simProvider.chartTime,
    );
  }
}
