import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../map/models/map_models.dart';
import '../../models/flight_log_models.dart';

class AnalysisTrackMap extends StatefulWidget {
  final FlightLog log;

  const AnalysisTrackMap({super.key, required this.log});

  @override
  State<AnalysisTrackMap> createState() => _AnalysisTrackMapState();
}

class _AnalysisTrackMapState extends State<AnalysisTrackMap> {
  bool _showDetail = false;

  @override
  Widget build(BuildContext context) {
    if (widget.log.points.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final points = widget.log.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);

    final baseLayer = _showDetail
        ? MapLayerStyle.satellite
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
              points: points,
              color: theme.colorScheme.primary,
              strokeWidth: 4,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: points.first,
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
              point: points.last,
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
      height: 360,
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
        ],
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
