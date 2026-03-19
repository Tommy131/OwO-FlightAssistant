import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/flight_logs_localization_keys.dart';
import '../../models/flight_log_models.dart';

class AnalysisChart extends StatefulWidget {
  final FlightLog log;

  const AnalysisChart({super.key, required this.log});

  @override
  State<AnalysisChart> createState() => _AnalysisChartState();
}

class _AnalysisChartState extends State<AnalysisChart> {
  final Set<_ChartMetric> _selectedMetrics = {
    _ChartMetric.altitude,
    _ChartMetric.speed,
    _ChartMetric.verticalSpeed,
    _ChartMetric.gForce,
  };

  @override
  Widget build(BuildContext context) {
    if (widget.log.points.length < 2) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final spotsByMetric = <_ChartMetric, List<FlSpot>>{
      _ChartMetric.altitude: <FlSpot>[],
      _ChartMetric.speed: <FlSpot>[],
      _ChartMetric.pitch: <FlSpot>[],
      _ChartMetric.verticalSpeed: <FlSpot>[],
      _ChartMetric.gForce: <FlSpot>[],
      _ChartMetric.baro: <FlSpot>[],
      _ChartMetric.aoa: <FlSpot>[],
    };

    for (int i = 0; i < widget.log.points.length; i++) {
      final point = widget.log.points[i];
      final time =
          point.timestamp
              .difference(widget.log.startTime)
              .inSeconds
              .toDouble() /
          60;
      spotsByMetric[_ChartMetric.altitude]!.add(FlSpot(time, point.altitude));
      spotsByMetric[_ChartMetric.speed]!.add(FlSpot(time, point.groundSpeed));
      spotsByMetric[_ChartMetric.pitch]!.add(FlSpot(time, point.pitch));
      spotsByMetric[_ChartMetric.verticalSpeed]!.add(
        FlSpot(time, point.verticalSpeed),
      );
      spotsByMetric[_ChartMetric.gForce]!.add(FlSpot(time, point.gForce));
      spotsByMetric[_ChartMetric.baro]!.add(
        FlSpot(time, point.baroPressure ?? 29.92),
      );
      spotsByMetric[_ChartMetric.aoa]!.add(FlSpot(time, point.angleOfAttack ?? 0));
    }
    final activeMetrics = _ChartMetric.values
        .where(_selectedMetrics.contains)
        .toList();
    final lineBars = activeMetrics.map((metric) {
      final color = _metricColor(metric);
      final showArea = metric == _ChartMetric.altitude || metric == _ChartMetric.gForce;
      return LineChartBarData(
        spots: spotsByMetric[metric]!,
        isCurved: true,
        color: color,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: showArea,
          color: color.withValues(alpha: showArea ? 0.08 : 0),
        ),
      );
    }).toList();

    return Container(
      height: 420,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ChartMetric.values.map((metric) {
              final selected = _selectedMetrics.contains(metric);
              return FilterChip(
                label: Text(_metricLabel(context, metric)),
                selected: selected,
                selectedColor: _metricColor(metric).withValues(alpha: 0.2),
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedMetrics.add(metric);
                    } else if (_selectedMetrics.length > 1) {
                      _selectedMetrics.remove(metric);
                    }
                  });
                },
              );
            }).toList(),
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
                        if (value.abs() >= 1000) {
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
                lineBarsData: lineBars,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) {
                        final metric = activeMetrics[s.barIndex];
                        final unit = _metricUnit(metric);
                        return LineTooltipItem(
                          '${_metricLabel(context, metric)}: ${s.y.toStringAsFixed(_metricPrecision(metric))} $unit',
                          TextStyle(
                            color: _metricColor(metric),
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _metricLabel(BuildContext context, _ChartMetric metric) {
    return switch (metric) {
      _ChartMetric.altitude => FlightLogsLocalizationKeys.chartAltitude.tr(context),
      _ChartMetric.speed => FlightLogsLocalizationKeys.chartSpeed.tr(context),
      _ChartMetric.pitch => FlightLogsLocalizationKeys.chartPitch.tr(context),
      _ChartMetric.verticalSpeed =>
        FlightLogsLocalizationKeys.chartVerticalSpeed.tr(context),
      _ChartMetric.gForce => FlightLogsLocalizationKeys.chartGForce.tr(context),
      _ChartMetric.baro => FlightLogsLocalizationKeys.chartBaro.tr(context),
      _ChartMetric.aoa => FlightLogsLocalizationKeys.chartAoa.tr(context),
    };
  }

  String _metricUnit(_ChartMetric metric) {
    return switch (metric) {
      _ChartMetric.altitude => 'ft',
      _ChartMetric.speed => 'kts',
      _ChartMetric.pitch => '°',
      _ChartMetric.verticalSpeed => 'fpm',
      _ChartMetric.gForce => 'G',
      _ChartMetric.baro => 'inHg',
      _ChartMetric.aoa => '°',
    };
  }

  int _metricPrecision(_ChartMetric metric) {
    return switch (metric) {
      _ChartMetric.gForce || _ChartMetric.baro || _ChartMetric.aoa => 2,
      _ChartMetric.pitch => 1,
      _ => 0,
    };
  }

  Color _metricColor(_ChartMetric metric) {
    return switch (metric) {
      _ChartMetric.altitude => Colors.blue,
      _ChartMetric.speed => Colors.orange,
      _ChartMetric.pitch => Colors.purple,
      _ChartMetric.verticalSpeed => Colors.teal,
      _ChartMetric.gForce => Colors.red,
      _ChartMetric.baro => Colors.indigo,
      _ChartMetric.aoa => Colors.green,
    };
  }
}

enum _ChartMetric { altitude, speed, pitch, verticalSpeed, gForce, baro, aoa }
