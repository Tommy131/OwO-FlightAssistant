import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/services/localization_service.dart';
import '../../../map/models/map_models.dart';
import '../../localization/flight_logs_localization_keys.dart';
import '../../models/flight_log_models.dart';

class AnalysisTrackMap extends StatefulWidget {
  final FlightLog log;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;

  const AnalysisTrackMap({
    super.key,
    required this.log,
    this.isFullscreen = false,
    this.onToggleFullscreen,
  });

  @override
  State<AnalysisTrackMap> createState() => _AnalysisTrackMapState();
}

class _AnalysisTrackMapState extends State<AnalysisTrackMap> {
  bool _showDetail = false;
  _HoveredTrackPoint? _hoveredPoint;

  @override
  Widget build(BuildContext context) {
    if (widget.log.points.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final mapHeight = widget.isFullscreen
        ? (screenHeight - 140).clamp(420.0, 1600.0)
        : (screenHeight *
                  (0.38 + 0.22 * ((screenHeight - 640) / 520).clamp(0.0, 1.0)))
              .clamp(320.0, 680.0);
    final sampledPoints = _sampleTrackPoints(
      widget.log.points,
      maxPoints: 1200,
    );
    final takeoffAt = widget.log.takeoffData?.timestamp;
    final landingAt = widget.log.landingData?.timestamp;
    final stageSegments = _buildTrackStageSegments(sampledPoints);
    final specialMarkers = _buildSpecialMarkers(context);
    final highlightedKeys = specialMarkers
        .map((marker) => _pointKey(marker.point))
        .toSet();

    double minLat = widget.log.points.first.latitude;
    double maxLat = widget.log.points.first.latitude;
    double minLon = widget.log.points.first.longitude;
    double maxLon = widget.log.points.first.longitude;

    for (final p in widget.log.points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);

    final baseLayer = _showDetail
        ? MapLayerStyle.taxiway
        : (isDark ? MapLayerStyle.dark : MapLayerStyle.terrain);

    Widget mapWidget = FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 10,
        minZoom: 3,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: mapTileUrl(baseLayer),
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.owo.flight_assistant',
        ),
        PolylineLayer(
          polylines: stageSegments
              .map(
                (segment) => Polyline(
                  points: segment.points,
                  color: _stageColor(segment.stage, theme),
                  strokeWidth: 4,
                ),
              )
              .toList(),
        ),
        MarkerLayer(
          markers: [
            ...sampledPoints.map((point) {
              final isHighlighted = highlightedKeys.contains(_pointKey(point));
              final markerStage = _resolveTrackStage(
                point: point,
                takeoffAt: takeoffAt,
                landingAt: landingAt,
              );
              final baseMarkerColor = _stageColor(markerStage, theme);
              final markerColor = isHighlighted
                  ? Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.2),
                      baseMarkerColor,
                    )
                  : baseMarkerColor;
              return Marker(
                point: LatLng(point.latitude, point.longitude),
                width: 12,
                height: 12,
                child: MouseRegion(
                  onEnter: (_) => setState(
                    () => _hoveredPoint = _HoveredTrackPoint(point: point),
                  ),
                  onExit: (_) {
                    if (_hoveredPoint?.point == point &&
                        _hoveredPoint?.label == null) {
                      setState(() => _hoveredPoint = null);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(
                      () => _hoveredPoint = _HoveredTrackPoint(point: point),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: markerColor.withValues(
                          alpha: isHighlighted ? 0.36 : 0.25,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: markerColor.withValues(
                            alpha: isHighlighted ? 0.9 : 0.65,
                          ),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            ...specialMarkers.map((spec) => _buildSpecialMarker(spec)),
          ],
        ),
      ],
    );

    if (isDark && _showDetail) {
      mapWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.7,
          0,
          0,
          0,
          0,
          0,
          0.7,
          0,
          0,
          0,
          0,
          0,
          0.7,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: mapWidget,
      );
    }

    return Container(
      height: mapHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: mapWidget),
          Positioned(
            top: 12,
            left: 12,
            child: _buildStageLegend(context, theme),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onToggleFullscreen != null) ...[
                  _MapActionButton(
                    icon: widget.isFullscreen
                        ? Icons.close_fullscreen_rounded
                        : Icons.open_in_full_rounded,
                    onTap: widget.onToggleFullscreen!,
                  ),
                  const SizedBox(width: 8),
                ],
                _LayerToggle(
                  isDetail: _showDetail,
                  onSelect: (value) {
                    setState(() => _showDetail = value);
                  },
                ),
              ],
            ),
          ),
          if (_hoveredPoint != null)
            Positioned(
              left: 12,
              bottom: 12,
              child: _TrackPointInfoCard(
                point: _hoveredPoint!.point,
                markerLabel: _hoveredPoint!.label,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStageLegend(BuildContext context, ThemeData theme) {
    final items = [
      (_TrackStage.taxiBeforeTakeoff, '起飞前滑行'),
      (_TrackStage.climb, '爬升中'),
      (_TrackStage.cruise, '巡航中'),
      (_TrackStage.approach, '进近中'),
      (_TrackStage.taxiAfterLanding, '落地后滑行'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: items.map((item) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: _stageColor(item.$1, theme),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                item.$2,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  List<_TrackStageSegment> _buildTrackStageSegments(
    List<FlightLogPoint> points,
  ) {
    if (points.length < 2) {
      return const <_TrackStageSegment>[];
    }
    final takeoffAt = widget.log.takeoffData?.timestamp;
    final landingAt = widget.log.landingData?.timestamp;
    final segments = <_TrackStageSegment>[];
    var currentStage = _resolveTrackStage(
      point: points.first,
      takeoffAt: takeoffAt,
      landingAt: landingAt,
    );
    var currentPoints = <LatLng>[
      LatLng(points.first.latitude, points.first.longitude),
    ];
    for (var i = 1; i < points.length; i++) {
      final point = points[i];
      final previousPoint = points[i - 1];
      final nextStage = _resolveTrackStage(
        point: point,
        takeoffAt: takeoffAt,
        landingAt: landingAt,
      );
      final currentLatLng = LatLng(point.latitude, point.longitude);
      if (nextStage != currentStage) {
        currentPoints.add(currentLatLng);
        if (currentPoints.length >= 2) {
          segments.add(
            _TrackStageSegment(stage: currentStage, points: currentPoints),
          );
        }
        currentStage = nextStage;
        currentPoints = <LatLng>[
          LatLng(previousPoint.latitude, previousPoint.longitude),
          currentLatLng,
        ];
      } else {
        currentPoints.add(currentLatLng);
      }
    }
    if (currentPoints.length >= 2) {
      segments.add(
        _TrackStageSegment(stage: currentStage, points: currentPoints),
      );
    }
    return segments;
  }

  _TrackStage _resolveTrackStage({
    required FlightLogPoint point,
    required DateTime? takeoffAt,
    required DateTime? landingAt,
  }) {
    final phase = (point.flightPhase ?? '').trim().toLowerCase();
    if (landingAt != null &&
        !point.timestamp.isBefore(landingAt) &&
        ((point.onGround ?? false) || phase == 'taxi' || phase == 'landing')) {
      return _TrackStage.taxiAfterLanding;
    }
    if (takeoffAt != null && point.timestamp.isBefore(takeoffAt)) {
      return _TrackStage.taxiBeforeTakeoff;
    }
    switch (phase) {
      case 'climb':
      case 'takeoff':
        return _TrackStage.climb;
      case 'cruise':
        return _TrackStage.cruise;
      case 'approach':
      case 'landing':
        return _TrackStage.approach;
      case 'taxi':
        if (landingAt != null && !point.timestamp.isBefore(landingAt)) {
          return _TrackStage.taxiAfterLanding;
        }
        return _TrackStage.taxiBeforeTakeoff;
    }
    if (point.onGround ?? false) {
      if (landingAt != null && !point.timestamp.isBefore(landingAt)) {
        return _TrackStage.taxiAfterLanding;
      }
      return _TrackStage.taxiBeforeTakeoff;
    }
    if (point.verticalSpeed <= -400 && point.altitude <= 9000) {
      return _TrackStage.approach;
    }
    if (point.altitude >= 12000 && point.verticalSpeed.abs() <= 700) {
      return _TrackStage.cruise;
    }
    return _TrackStage.climb;
  }

  Color _stageColor(_TrackStage stage, ThemeData theme) {
    return switch (stage) {
      _TrackStage.taxiBeforeTakeoff => Colors.amberAccent,
      _TrackStage.climb => Colors.cyanAccent,
      _TrackStage.cruise => Colors.deepPurpleAccent,
      _TrackStage.approach => Colors.deepOrangeAccent,
      _TrackStage.taxiAfterLanding => Colors.greenAccent,
    };
  }

  String _pointKey(FlightLogPoint point) {
    return point.timestamp.millisecondsSinceEpoch.toString();
  }

  Marker _buildSpecialMarker(_MapMarkerSpec spec) {
    final markerSize = spec.emphasized ? 34.0 : 28.0;
    final iconSize = spec.emphasized ? 18.0 : 16.0;
    return Marker(
      point: LatLng(spec.point.latitude, spec.point.longitude),
      width: markerSize,
      height: markerSize,
      child: MouseRegion(
        onEnter: (_) => setState(
          () => _hoveredPoint = _HoveredTrackPoint(
            point: spec.point,
            label: spec.label,
          ),
        ),
        onExit: (_) {
          if (_hoveredPoint?.point == spec.point &&
              _hoveredPoint?.label == spec.label) {
            setState(() => _hoveredPoint = null);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(
            () => _hoveredPoint = _HoveredTrackPoint(
              point: spec.point,
              label: spec.label,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: spec.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.6),
            ),
            child: Icon(spec.icon, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }

  List<_MapMarkerSpec> _buildSpecialMarkers(BuildContext context) {
    final points = widget.log.points;
    if (points.isEmpty) {
      return const [];
    }
    final markers = <_MapMarkerSpec>[
      _MapMarkerSpec(
        point: points.first,
        label: FlightLogsLocalizationKeys.startRecord.tr(context),
        color: Colors.green,
        icon: Icons.play_arrow_rounded,
      ),
      _MapMarkerSpec(
        point: points.last,
        label: FlightLogsLocalizationKeys.stopRecord.tr(context),
        color: Colors.red,
        icon: Icons.stop_rounded,
      ),
    ];
    final takeoffData = widget.log.takeoffData;
    if (takeoffData != null) {
      final takeoffPoint = _nearestPointByTimestamp(takeoffData.timestamp);
      if (takeoffPoint != null) {
        markers.add(
          _MapMarkerSpec(
            point: takeoffPoint,
            label: FlightLogsLocalizationKeys.chartEventTakeoff.tr(context),
            color: Colors.blue,
            icon: Icons.flight_takeoff,
            emphasized: true,
          ),
        );
      }
    }
    final touchdownSequence =
        widget.log.landingData?.touchdownSequence ?? const [];
    final touchdownGForces =
        widget.log.landingData?.touchdownGForces ?? const [];
    final finalTouchdownAt = widget.log.landingData?.timestamp;
    if (touchdownSequence.isNotEmpty) {
      for (var i = 0; i < touchdownSequence.length; i++) {
        final touchdown = _nearestPointByTimestamp(
          touchdownSequence[i].timestamp,
        );
        if (touchdown == null) {
          continue;
        }
        final touchdownG = i < touchdownGForces.length
            ? touchdownGForces[i]
            : touchdownSequence[i].gForce;
        final isFinal =
            finalTouchdownAt != null &&
            touchdown.timestamp.isAtSameMomentAs(finalTouchdownAt);
        final baseLabel = isFinal
            ? FlightLogsLocalizationKeys.chartEventFinalTouchdown.tr(context)
            : FlightLogsLocalizationKeys.chartEventTouchdown.tr(context);
        final label = '$baseLabel ${i + 1} (${touchdownG.toStringAsFixed(2)}G)';
        markers.add(
          _MapMarkerSpec(
            point: touchdown,
            label: label,
            color: isFinal ? Colors.redAccent : Colors.deepOrange,
            icon: Icons.flight_land,
            emphasized: isFinal,
          ),
        );
      }
    } else if (widget.log.landingData != null) {
      final landingPoint = _nearestPointByTimestamp(
        widget.log.landingData!.timestamp,
      );
      if (landingPoint != null) {
        markers.add(
          _MapMarkerSpec(
            point: landingPoint,
            label: FlightLogsLocalizationKeys.chartEventFinalTouchdown.tr(
              context,
            ),
            color: Colors.redAccent,
            icon: Icons.flight_land,
            emphasized: true,
          ),
        );
      }
    }
    bool? previousGearDown = points.first.gearDown;
    for (var i = 1; i < points.length; i++) {
      final point = points[i];
      final currentGearDown = point.gearDown;
      if (currentGearDown != null &&
          previousGearDown != null &&
          currentGearDown != previousGearDown) {
        final isDown = currentGearDown;
        markers.add(
          _MapMarkerSpec(
            point: point,
            label: isDown
                ? FlightLogsLocalizationKeys.chartEventGearDown.tr(context)
                : FlightLogsLocalizationKeys.chartEventGearUp.tr(context),
            color: isDown ? Colors.green : Colors.orangeAccent,
            icon: isDown ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
          ),
        );
      }
      previousGearDown = currentGearDown ?? previousGearDown;
    }
    return markers;
  }

  FlightLogPoint? _nearestPointByTimestamp(DateTime timestamp) {
    if (widget.log.points.isEmpty) {
      return null;
    }
    FlightLogPoint nearest = widget.log.points.first;
    var minDiff = nearest.timestamp.difference(timestamp).inMilliseconds.abs();
    for (final point in widget.log.points) {
      final diff = point.timestamp.difference(timestamp).inMilliseconds.abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = point;
      }
    }
    return nearest;
  }

  List<FlightLogPoint> _sampleTrackPoints(
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
}

class _TrackPointInfoCard extends StatelessWidget {
  final FlightLogPoint point;
  final String? markerLabel;

  const _TrackPointInfoCard({required this.point, this.markerLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <_InfoEntry>[
      _InfoEntry(
        FlightLogsLocalizationKeys.blackBoxTime.tr(context),
        point.timestamp.toUtc().toIso8601String().substring(11, 19),
      ),
      _InfoEntry(
        FlightLogsLocalizationKeys.chartAltitude.tr(context),
        '${point.altitude.toStringAsFixed(0)} ft',
      ),
      _InfoEntry(
        FlightLogsLocalizationKeys.chartSpeed.tr(context),
        '${point.groundSpeed.toStringAsFixed(0)} kts',
      ),
      _InfoEntry(
        FlightLogsLocalizationKeys.chartPitch.tr(context),
        '${point.pitch.toStringAsFixed(1)}°',
      ),
      _InfoEntry(
        FlightLogsLocalizationKeys.chartVerticalSpeed.tr(context),
        '${point.verticalSpeed.toStringAsFixed(0)} fpm',
      ),
      _InfoEntry(
        FlightLogsLocalizationKeys.chartGForce.tr(context),
        point.gForce.toStringAsFixed(2),
      ),
      _InfoEntry(
        FlightLogsLocalizationKeys.chartBaro.tr(context),
        '${(point.baroPressure ?? 29.92).toStringAsFixed(2)} inHg',
      ),
      _InfoEntry(
        FlightLogsLocalizationKeys.chartAoa.tr(context),
        point.angleOfAttack != null
            ? '${point.angleOfAttack!.toStringAsFixed(2)}°'
            : '-',
      ),
    ];

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 250,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (markerLabel != null && markerLabel!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.place_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        markerLabel!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ...rows.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.hintColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.value,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _HoveredTrackPoint {
  final FlightLogPoint point;
  final String? label;

  const _HoveredTrackPoint({required this.point, this.label});
}

class _MapMarkerSpec {
  final FlightLogPoint point;
  final String label;
  final Color color;
  final IconData icon;
  final bool emphasized;

  const _MapMarkerSpec({
    required this.point,
    required this.label,
    required this.color,
    required this.icon,
    this.emphasized = false,
  });
}

class _InfoEntry {
  final String label;
  final String value;

  const _InfoEntry(this.label, this.value);
}

enum _TrackStage {
  taxiBeforeTakeoff,
  climb,
  cruise,
  approach,
  taxiAfterLanding,
}

class _TrackStageSegment {
  final _TrackStage stage;
  final List<LatLng> points;

  const _TrackStageSegment({required this.stage, required this.points});
}

class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}

class _LayerToggle extends StatelessWidget {
  final bool isDetail;
  final ValueChanged<bool> onSelect;

  const _LayerToggle({required this.isDetail, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            label: '简约',
            selected: !isDetail,
            onTap: () => onSelect(false),
          ),
          const SizedBox(width: 4),
          _ToggleChip(
            label: '详情',
            selected: isDetail,
            onTap: () => onSelect(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.15)
        : Colors.transparent;
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color.withValues(alpha: selected ? 1 : 0.7),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
