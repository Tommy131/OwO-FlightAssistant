import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/services/localization_service.dart';
import '../../../map/models/map_models.dart';
import '../../localization/flight_logs_localization_keys.dart';
import '../../models/flight_log_models.dart';

class AnalysisTrackMap extends StatefulWidget {
  final FlightLog log;

  const AnalysisTrackMap({super.key, required this.log});

  @override
  State<AnalysisTrackMap> createState() => _AnalysisTrackMapState();
}

class _AnalysisTrackMapState extends State<AnalysisTrackMap> {
  bool _showDetail = false;
  FlightLogPoint? _hoveredPoint;

  @override
  Widget build(BuildContext context) {
    if (widget.log.points.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heightProgress = ((screenHeight - 640) / 520).clamp(0.0, 1.0);
    final mapHeightFactor = 0.38 + 0.22 * heightProgress;
    final mapHeight = (screenHeight * mapHeightFactor).clamp(320.0, 680.0);
    final sampledPoints = _sampleTrackPoints(
      widget.log.points,
      maxPoints: 1200,
    );
    final trackPoints = sampledPoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

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
          polylines: [
            Polyline(
              points: trackPoints,
              color: theme.colorScheme.primary,
              strokeWidth: 4,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            ...sampledPoints.map((point) {
              return Marker(
                point: LatLng(point.latitude, point.longitude),
                width: 12,
                height: 12,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hoveredPoint = point),
                  onExit: (_) {
                    if (_hoveredPoint == point) {
                      setState(() => _hoveredPoint = null);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _hoveredPoint = point),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.25,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.65,
                          ),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            Marker(
              point: LatLng(
                widget.log.points.first.latitude,
                widget.log.points.first.longitude,
              ),
              width: 24,
              height: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.green,
                  size: 14,
                ),
              ),
            ),
            Marker(
              point: LatLng(
                widget.log.points.last.latitude,
                widget.log.points.last.longitude,
              ),
              width: 24,
              height: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: const Icon(
                  Icons.stop_rounded,
                  color: Colors.red,
                  size: 14,
                ),
              ),
            ),
            if (widget.log.takeoffData != null)
              Marker(
                point: LatLng(
                  widget.log.takeoffData!.latitude,
                  widget.log.takeoffData!.longitude,
                ),
                width: 32,
                height: 32,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flight_takeoff,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            if (widget.log.landingData != null)
              Marker(
                point: LatLng(
                  widget.log.landingData!.latitude,
                  widget.log.landingData!.longitude,
                ),
                width: 32,
                height: 32,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flight_land,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
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
            right: 12,
            child: _LayerToggle(
              isDetail: _showDetail,
              onSelect: (value) {
                setState(() => _showDetail = value);
              },
            ),
          ),
          if (_hoveredPoint != null)
            Positioned(
              left: 12,
              bottom: 12,
              child: _TrackPointInfoCard(point: _hoveredPoint!),
            ),
        ],
      ),
    );
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

  const _TrackPointInfoCard({required this.point});

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
          children: rows.map((entry) {
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
          }).toList(),
        ),
      ),
    );
  }
}

class _InfoEntry {
  final String label;
  final String value;

  const _InfoEntry(this.label, this.value);
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
