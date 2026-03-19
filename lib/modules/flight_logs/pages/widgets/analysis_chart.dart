import 'dart:math' as math;

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
  final Set<_ChartEventType> _selectedEvents = {..._ChartEventType.values};
  double _xZoom = 1;
  double _yZoom = 1;

  @override
  Widget build(BuildContext context) {
    if (widget.log.points.length < 2) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sampledPoints = _samplePoints(widget.log.points, maxPoints: 900);
    final spotsByMetric = <_ChartMetric, List<FlSpot>>{
      _ChartMetric.altitude: <FlSpot>[],
      _ChartMetric.speed: <FlSpot>[],
      _ChartMetric.pitch: <FlSpot>[],
      _ChartMetric.verticalSpeed: <FlSpot>[],
      _ChartMetric.gForce: <FlSpot>[],
      _ChartMetric.baro: <FlSpot>[],
      _ChartMetric.aoa: <FlSpot>[],
    };

    for (int i = 0; i < sampledPoints.length; i++) {
      final point = sampledPoints[i];
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
      final aoa = point.angleOfAttack;
      if (aoa != null) {
        spotsByMetric[_ChartMetric.aoa]!.add(FlSpot(time, aoa));
      }
    }
    final activeMetrics = _ChartMetric.values
        .where(
          (metric) =>
              _selectedMetrics.contains(metric) &&
              spotsByMetric[metric]!.isNotEmpty,
        )
        .toList();
    final showSingleSelectionNoData =
        _selectedMetrics.length == 1 && activeMetrics.isEmpty;
    final allEventMarkers = _buildEventMarkers(context, widget.log.points);
    final availableEventTypes = _ChartEventType.values
        .where((type) => allEventMarkers.any((marker) => marker.type == type))
        .toList();
    final eventMarkers = allEventMarkers
        .where((marker) => _selectedEvents.contains(marker.type))
        .toList();
    final totalDuration = _timeInMinutes(widget.log.points.last.timestamp);
    final minX = 0.0;
    final maxX = _resolveMaxX(totalDuration);
    final minY = _resolveMinY(activeMetrics, spotsByMetric);
    final maxY = _resolveMaxY(activeMetrics, spotsByMetric);
    final lineBars = <LineChartBarData>[];
    final chartSeries = <_ChartSeriesEntry>[];
    for (final metric in activeMetrics) {
      final color = _metricColor(metric);
      final showArea =
          metric == _ChartMetric.altitude || metric == _ChartMetric.gForce;
      lineBars.add(
        LineChartBarData(
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
        ),
      );
      chartSeries.add(
        _ChartSeriesEntry.metric(
          label: _metricLabel(context, metric),
          color: color,
          unit: _metricUnit(metric),
          precision: _metricPrecision(metric),
        ),
      );
    }
    if (activeMetrics.isNotEmpty) {
      for (final marker in eventMarkers) {
        final y = _resolveMarkerY(
          point: marker.point,
          time: marker.timeInMinutes,
          activeMetric: activeMetrics.first,
          spotsByMetric: spotsByMetric,
        );
        if (y == null) continue;
        lineBars.add(
          LineChartBarData(
            spots: [FlSpot(marker.timeInMinutes, y)],
            isCurved: false,
            color: Colors.transparent,
            barWidth: 1,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: marker.type == _ChartEventType.finalTouchdown ? 5 : 4,
                color: marker.color,
                strokeWidth: 1.6,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(show: false),
          ),
        );
        chartSeries.add(
          _ChartSeriesEntry.event(label: marker.label, color: marker.color),
        );
      }
    }

    return Column(
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
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableEventTypes.map((eventType) {
            final selected = _selectedEvents.contains(eventType);
            return FilterChip(
              label: Text(_eventTypeLabel(context, eventType)),
              selected: selected,
              selectedColor: _eventColor(eventType).withValues(alpha: 0.2),
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _selectedEvents.add(eventType);
                  } else {
                    _selectedEvents.remove(eventType);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          FlightLogsLocalizationKeys.chartScaleHelp.tr(context),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 12),
        Container(
          height: 420,
          padding: const EdgeInsets.all(AppThemeData.spacingMedium),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: showSingleSelectionNoData
              ? Center(
                  child: Text(
                    FlightLogsLocalizationKeys.chartNoData.tr(context),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.hintColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final chartWidth = constraints.maxWidth;
                    final chartHeight = constraints.maxHeight;
                    final xTargetTicks = (chartWidth / 90).clamp(3, 8).toInt();
                    final yTargetTicks = (chartHeight / 54).clamp(3, 8).toInt();
                    final xInterval = _niceInterval(
                      (maxX - minX) / xTargetTicks,
                    );
                    final yInterval = _niceInterval(
                      (maxY - minY) / yTargetTicks,
                    );
                    return LineChart(
                      LineChartData(
                        clipData: const FlClipData.all(),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: yInterval,
                          verticalInterval: xInterval,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: theme.dividerColor.withValues(alpha: 0.08),
                            strokeWidth: 0.8,
                          ),
                          getDrawingVerticalLine: (value) => FlLine(
                            color: theme.dividerColor.withValues(alpha: 0.07),
                            strokeWidth: 0.7,
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
                              interval: xInterval,
                              getTitlesWidget: (value, meta) {
                                return GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onPanUpdate: (details) {
                                    _handleHorizontalScaleDrag(
                                      details.delta.dx,
                                    );
                                  },
                                  child: Text(
                                    '${_formatAxisValue(value)} ${FlightLogsLocalizationKeys.chartMinuteUnit.tr(context)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 56,
                              interval: yInterval,
                              getTitlesWidget: (value, meta) {
                                final text = value.abs() >= 1000
                                    ? '${_formatAxisValue(value / 1000)} k'
                                    : _formatAxisValue(value);
                                return GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onPanUpdate: (details) {
                                    _handleVerticalScaleDrag(details.delta.dy);
                                  },
                                  child: Text(
                                    text,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        minX: minX,
                        maxX: maxX,
                        minY: minY,
                        maxY: maxY,
                        borderData: FlBorderData(show: false),
                        lineBarsData: lineBars,
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((s) {
                                final series = chartSeries[s.barIndex];
                                if (!series.showValue) {
                                  return LineTooltipItem(
                                    series.label,
                                    TextStyle(
                                      color: series.color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                final value = s.y.toStringAsFixed(
                                  series.precision,
                                );
                                final suffix = series.unit.isEmpty
                                    ? ''
                                    : ' ${series.unit}';
                                return LineTooltipItem(
                                  '${series.label}: $value$suffix',
                                  TextStyle(
                                    color: series.color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<FlightLogPoint> _samplePoints(
    List<FlightLogPoint> points, {
    required int maxPoints,
  }) {
    if (points.length <= maxPoints) {
      return points;
    }
    final step = (points.length - 1) / (maxPoints - 1);
    final sampled = <FlightLogPoint>[];
    for (int i = 0; i < maxPoints; i++) {
      final index = (i * step).round().clamp(0, points.length - 1);
      sampled.add(points[index]);
    }
    return sampled;
  }

  Iterable<_ChartEventMarker> _buildEventMarkers(
    BuildContext context,
    List<FlightLogPoint> points,
  ) {
    final markers = <_ChartEventMarker>[];
    final touchdownMarkers = <_ChartEventMarker>[];
    var previousOnGround = widget.log.wasOnGroundAtStart;
    var takeoffCaptured = false;
    var previousFlapsToken = '';
    double? previousFlapsLevel;
    var flapsInitialized = false;
    var touchdownCount = 0;
    for (final point in points) {
      final time = _timeInMinutes(point.timestamp);
      final currentOnGround = point.onGround ?? previousOnGround;
      if (!takeoffCaptured && !currentOnGround) {
        markers.add(
          _ChartEventMarker(
            type: _ChartEventType.takeoff,
            label: _eventTypeLabel(context, _ChartEventType.takeoff),
            color: _eventColor(_ChartEventType.takeoff),
            point: point,
            timeInMinutes: time,
          ),
        );
        takeoffCaptured = true;
      }
      final currentFlapsLevel = _flapsLevel(point);
      final currentFlapsToken = _flapsToken(point);
      if (!flapsInitialized) {
        previousFlapsLevel = currentFlapsLevel;
        previousFlapsToken = currentFlapsToken;
        flapsInitialized = true;
      } else {
        final hasFlapsChange =
            currentFlapsLevel != null &&
            currentFlapsToken.isNotEmpty &&
            currentFlapsToken != previousFlapsToken;
        if (hasFlapsChange) {
          final isDeploy =
              previousFlapsLevel == null ||
              currentFlapsLevel > previousFlapsLevel;
          final eventType = isDeploy
              ? _ChartEventType.flapsDeploy
              : _ChartEventType.flapsRetract;
          final actionLabel = _eventTypeLabel(context, eventType);
          markers.add(
            _ChartEventMarker(
              type: eventType,
              label: '$actionLabel ${_flapsLabel(point)}',
              color: _eventColor(eventType),
              point: point,
              timeInMinutes: time,
            ),
          );
        }
      }
      if (!previousOnGround && currentOnGround) {
        touchdownCount += 1;
        touchdownMarkers.add(
          _ChartEventMarker(
            type: _ChartEventType.touchdown,
            label:
                '${_eventTypeLabel(context, _ChartEventType.touchdown)} $touchdownCount',
            color: _eventColor(_ChartEventType.touchdown),
            point: point,
            timeInMinutes: time,
          ),
        );
      }
      previousOnGround = currentOnGround;
      previousFlapsLevel = currentFlapsLevel ?? previousFlapsLevel;
      previousFlapsToken = currentFlapsToken;
    }
    if (touchdownMarkers.length == 1) {
      final firstTouchdown = touchdownMarkers.first;
      markers.add(
        _ChartEventMarker(
          type: _ChartEventType.finalTouchdown,
          label: _eventTypeLabel(context, _ChartEventType.finalTouchdown),
          color: _eventColor(_ChartEventType.finalTouchdown),
          point: firstTouchdown.point,
          timeInMinutes: firstTouchdown.timeInMinutes,
        ),
      );
    } else if (touchdownMarkers.length > 1) {
      markers.addAll(touchdownMarkers);
      final lastTouchdown = touchdownMarkers.last;
      markers.add(
        _ChartEventMarker(
          type: _ChartEventType.finalTouchdown,
          label:
              '${_eventTypeLabel(context, _ChartEventType.finalTouchdown)} ${touchdownMarkers.length}',
          color: _eventColor(_ChartEventType.finalTouchdown),
          point: lastTouchdown.point,
          timeInMinutes: lastTouchdown.timeInMinutes,
        ),
      );
    }
    return markers;
  }

  double _timeInMinutes(DateTime timestamp) {
    return timestamp.difference(widget.log.startTime).inSeconds.toDouble() / 60;
  }

  double _resolveMaxX(double totalDuration) {
    final duration = totalDuration <= 0 ? 1.0 : totalDuration;
    final zoomed = duration / _xZoom;
    return zoomed.clamp(1.0, duration).toDouble();
  }

  double _resolveMinY(
    List<_ChartMetric> activeMetrics,
    Map<_ChartMetric, List<FlSpot>> spotsByMetric,
  ) {
    if (activeMetrics.isEmpty) return 0;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final metric in activeMetrics) {
      for (final spot in spotsByMetric[metric] ?? const <FlSpot>[]) {
        if (spot.y < minY) minY = spot.y;
        if (spot.y > maxY) maxY = spot.y;
      }
    }
    if (!minY.isFinite || !maxY.isFinite) return 0;
    final span = (maxY - minY).abs();
    final baseSpan = span < 1 ? 1.0 : span;
    final zoomedSpan = baseSpan / _yZoom;
    final center = (minY + maxY) / 2;
    return center - zoomedSpan / 2;
  }

  double _resolveMaxY(
    List<_ChartMetric> activeMetrics,
    Map<_ChartMetric, List<FlSpot>> spotsByMetric,
  ) {
    if (activeMetrics.isEmpty) return 1;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final metric in activeMetrics) {
      for (final spot in spotsByMetric[metric] ?? const <FlSpot>[]) {
        if (spot.y < minY) minY = spot.y;
        if (spot.y > maxY) maxY = spot.y;
      }
    }
    if (!minY.isFinite || !maxY.isFinite) return 1;
    final span = (maxY - minY).abs();
    final baseSpan = span < 1 ? 1.0 : span;
    final zoomedSpan = baseSpan / _yZoom;
    final center = (minY + maxY) / 2;
    return center + zoomedSpan / 2;
  }

  double _niceInterval(double raw) {
    if (!raw.isFinite || raw <= 0) return 1;
    final exponent = (math.log(raw.abs()) / math.ln10).floor();
    final base = raw / _pow10(exponent);
    if (base <= 1) return 1 * _pow10(exponent);
    if (base <= 2) return 2 * _pow10(exponent);
    if (base <= 5) return 5 * _pow10(exponent);
    return 10 * _pow10(exponent);
  }

  double _pow10(int exponent) {
    if (exponent == 0) return 1;
    final positive = exponent.abs();
    var result = 1.0;
    for (var i = 0; i < positive; i++) {
      result *= 10;
    }
    return exponent > 0 ? result : 1 / result;
  }

  String _formatAxisValue(double value) {
    if (value.abs() >= 100) {
      return value.toStringAsFixed(0);
    }
    if (value.abs() >= 10) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(2);
  }

  void _handleHorizontalScaleDrag(double deltaX) {
    final next = (_xZoom * (1 + (-deltaX / 260))).clamp(1.0, 8.0).toDouble();
    if ((next - _xZoom).abs() < 0.01) return;
    setState(() {
      _xZoom = next;
    });
  }

  void _handleVerticalScaleDrag(double deltaY) {
    final next = (_yZoom * (1 + (-deltaY / 260))).clamp(1.0, 8.0).toDouble();
    if ((next - _yZoom).abs() < 0.01) return;
    setState(() {
      _yZoom = next;
    });
  }

  double? _resolveMarkerY({
    required FlightLogPoint point,
    required double time,
    required _ChartMetric activeMetric,
    required Map<_ChartMetric, List<FlSpot>> spotsByMetric,
  }) {
    final value = _metricValue(point, activeMetric);
    if (value != null) return value;
    return _nearestSpotY(spotsByMetric[activeMetric] ?? const [], time);
  }

  double? _metricValue(FlightLogPoint point, _ChartMetric metric) {
    return switch (metric) {
      _ChartMetric.altitude => point.altitude,
      _ChartMetric.speed => point.groundSpeed,
      _ChartMetric.pitch => point.pitch,
      _ChartMetric.verticalSpeed => point.verticalSpeed,
      _ChartMetric.gForce => point.gForce,
      _ChartMetric.baro => point.baroPressure ?? 29.92,
      _ChartMetric.aoa => point.angleOfAttack,
    };
  }

  double? _nearestSpotY(List<FlSpot> spots, double x) {
    if (spots.isEmpty) return null;
    FlSpot nearest = spots.first;
    double minDistance = (nearest.x - x).abs();
    for (final spot in spots) {
      final distance = (spot.x - x).abs();
      if (distance < minDistance) {
        minDistance = distance;
        nearest = spot;
      }
    }
    return nearest.y;
  }

  String _flapsToken(FlightLogPoint point) {
    if (point.flapsPosition != null) return point.flapsPosition!.toString();
    final label = point.flapsLabel?.trim() ?? '';
    return label;
  }

  String _flapsLabel(FlightLogPoint point) {
    final level = _flapsLevel(point);
    if (level != null) {
      if (level == level.roundToDouble()) {
        return '${level.toInt()}°';
      }
      return '${level.toStringAsFixed(1)}°';
    }
    final label = point.flapsLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
    return '0°';
  }

  double? _flapsLevel(FlightLogPoint point) {
    if (point.flapsPosition != null) {
      return point.flapsPosition!.toDouble();
    }
    final label = point.flapsLabel?.trim();
    if (label == null || label.isEmpty) return null;
    final lower = label.toLowerCase();
    if (lower == 'up' || lower == '0') return 0;
    final match = RegExp(r'-?\d+(\.\d+)?').firstMatch(label);
    if (match == null) return null;
    return double.tryParse(match.group(0) ?? '');
  }

  String _eventTypeLabel(BuildContext context, _ChartEventType eventType) {
    return switch (eventType) {
      _ChartEventType.takeoff =>
        FlightLogsLocalizationKeys.chartEventTakeoff.tr(context),
      _ChartEventType.flapsDeploy =>
        FlightLogsLocalizationKeys.chartEventFlapsDeploy.tr(context),
      _ChartEventType.flapsRetract =>
        FlightLogsLocalizationKeys.chartEventFlapsRetract.tr(context),
      _ChartEventType.touchdown =>
        FlightLogsLocalizationKeys.chartEventTouchdown.tr(context),
      _ChartEventType.finalTouchdown =>
        FlightLogsLocalizationKeys.chartEventFinalTouchdown.tr(context),
    };
  }

  Color _eventColor(_ChartEventType eventType) {
    return switch (eventType) {
      _ChartEventType.takeoff => Colors.lightBlue,
      _ChartEventType.flapsDeploy => Colors.deepPurple,
      _ChartEventType.flapsRetract => Colors.purpleAccent,
      _ChartEventType.touchdown => Colors.deepOrange,
      _ChartEventType.finalTouchdown => Colors.redAccent,
    };
  }

  String _metricLabel(BuildContext context, _ChartMetric metric) {
    return switch (metric) {
      _ChartMetric.altitude => FlightLogsLocalizationKeys.chartAltitude.tr(
        context,
      ),
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

enum _ChartEventType {
  takeoff,
  flapsDeploy,
  flapsRetract,
  touchdown,
  finalTouchdown,
}

class _ChartEventMarker {
  final _ChartEventType type;
  final String label;
  final Color color;
  final FlightLogPoint point;
  final double timeInMinutes;

  const _ChartEventMarker({
    required this.type,
    required this.label,
    required this.color,
    required this.point,
    required this.timeInMinutes,
  });
}

class _ChartSeriesEntry {
  final String label;
  final Color color;
  final String unit;
  final int precision;
  final bool showValue;

  const _ChartSeriesEntry.metric({
    required this.label,
    required this.color,
    required this.unit,
    required this.precision,
  }) : showValue = true;

  const _ChartSeriesEntry.event({required this.label, required this.color})
    : unit = '',
      precision = 0,
      showValue = false;
}
