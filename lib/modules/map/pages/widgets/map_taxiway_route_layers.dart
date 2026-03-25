import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/map_models.dart';

class TaxiwayRoutePolylineLayer extends StatelessWidget {
  final List<MapTaxiwayNode> nodes;
  final List<MapTaxiwaySegment> segments;
  final Set<int> completedSegmentIndexes;
  final double scale;
  final bool enableSegmentMenu;
  final void Function(int segmentIndex, Offset globalPosition)?
  onSegmentSecondaryTap;
  final void Function(int segmentIndex, Offset globalPosition)? onSegmentTap;
  final void Function(int segmentIndex, Offset globalPosition)? onSegmentHover;
  final VoidCallback? onSegmentHoverEnd;
  final void Function(int segmentIndex, Offset globalPosition)?
  onSegmentLongPress;

  const TaxiwayRoutePolylineLayer({
    super.key,
    required this.nodes,
    required this.segments,
    this.completedSegmentIndexes = const <int>{},
    required this.scale,
    this.enableSegmentMenu = false,
    this.onSegmentSecondaryTap,
    this.onSegmentTap,
    this.onSegmentHover,
    this.onSegmentHoverEnd,
    this.onSegmentLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (nodes.length < 2) {
      return const SizedBox.shrink();
    }
    final segmentCount = nodes.length - 1;
    final hitNotifier = ValueNotifier<LayerHitResult<int>?>(null);
    final polylines = List<Polyline<int>>.generate(segmentCount, (index) {
      final segment = index < segments.length
          ? segments[index]
          : const MapTaxiwaySegment();
      final segmentPoints = _buildSegmentPolylinePoints(
        start: nodes[index],
        end: nodes[index + 1],
        segment: segment,
      );
      return Polyline<int>(
        points: segmentPoints,
        color: _resolveSegmentColor(
          segment.colorHex,
          isCompleted: completedSegmentIndexes.contains(index),
        ),
        strokeWidth: (4.2 * scale).clamp(3.0, 6.5),
        borderColor: Colors.black.withValues(alpha: 0.5),
        borderStrokeWidth: (1.4 * scale).clamp(1.0, 2.0),
        hitValue: index,
      );
    });
    final labelMarkers = List<Marker>.generate(segmentCount, (index) {
      final segment = index < segments.length
          ? segments[index]
          : const MapTaxiwaySegment();
      final label = segment.name?.trim();
      final labelPoint = _segmentLabelPoint(
        start: nodes[index],
        end: nodes[index + 1],
        segment: segment,
      );
      if (label == null || label.isEmpty) {
        return Marker(
          point: labelPoint,
          width: 1,
          height: 1,
          child: const SizedBox.shrink(),
        );
      }
      return Marker(
        point: labelPoint,
        width: 220 * scale,
        height: 28 * scale,
        child: IgnorePointer(
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 8 * scale,
                vertical: 3 * scale,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.66),
                borderRadius: BorderRadius.circular(8 * scale),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    });
    void triggerSegmentMenu(Offset globalPosition) {
      final hitResult = hitNotifier.value;
      if (!enableSegmentMenu ||
          hitResult == null ||
          hitResult.hitValues.isEmpty) {
        return;
      }
      final segmentIndex = hitResult.hitValues.first;
      onSegmentSecondaryTap?.call(segmentIndex, globalPosition);
    }

    void triggerSegmentTap(Offset globalPosition) {
      final hitResult = hitNotifier.value;
      if (hitResult == null || hitResult.hitValues.isEmpty) {
        return;
      }
      final segmentIndex = hitResult.hitValues.first;
      onSegmentTap?.call(segmentIndex, globalPosition);
    }

    void triggerSegmentLongPress(Offset globalPosition) {
      final hitResult = hitNotifier.value;
      if (!enableSegmentMenu ||
          hitResult == null ||
          hitResult.hitValues.isEmpty) {
        return;
      }
      final segmentIndex = hitResult.hitValues.first;
      onSegmentLongPress?.call(segmentIndex, globalPosition);
    }

    void triggerSegmentHover(Offset globalPosition) {
      final hitResult = hitNotifier.value;
      if (hitResult == null || hitResult.hitValues.isEmpty) {
        onSegmentHoverEnd?.call();
        return;
      }
      final segmentIndex = hitResult.hitValues.first;
      onSegmentHover?.call(segmentIndex, globalPosition);
    }

    return Stack(
      children: [
        MouseRegion(
          onHover: (event) {
            triggerSegmentHover(event.position);
          },
          onExit: (_) {
            onSegmentHoverEnd?.call();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onSecondaryTapDown: (details) {
              triggerSegmentMenu(details.globalPosition);
            },
            onTapDown: (details) {
              triggerSegmentTap(details.globalPosition);
            },
            onLongPressStart: (details) {
              triggerSegmentLongPress(details.globalPosition);
            },
            child: PolylineLayer<int>(
              polylines: polylines,
              hitNotifier: hitNotifier,
              minimumHitbox: 18,
            ),
          ),
        ),
        MarkerLayer(markers: labelMarkers),
      ],
    );
  }
}

class TaxiwayRoutePointMarkerLayer extends StatelessWidget {
  final List<MapTaxiwayNode> nodes;
  final Set<int> completedNodeIndexes;
  final double scale;
  final int? selectedIndex;
  final int? draggingIndex;
  final ValueChanged<int>? onNodeTap;
  final ValueChanged<int>? onNodeDragStart;
  final void Function(int index, Offset globalPosition)? onNodeDragUpdate;
  final VoidCallback? onNodeDragEnd;
  final void Function(int index, Offset globalPosition)? onNodeHover;
  final VoidCallback? onNodeHoverEnd;

  const TaxiwayRoutePointMarkerLayer({
    super.key,
    required this.nodes,
    this.completedNodeIndexes = const <int>{},
    required this.scale,
    this.selectedIndex,
    this.draggingIndex,
    this.onNodeTap,
    this.onNodeDragStart,
    this.onNodeDragUpdate,
    this.onNodeDragEnd,
    this.onNodeHover,
    this.onNodeHoverEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const SizedBox.shrink();
    }
    return MarkerLayer(
      markers: nodes
          .asMap()
          .entries
          .map(
            (entry) => Marker(
              point: LatLng(entry.value.latitude, entry.value.longitude),
              width: 28 * scale,
              height: 28 * scale,
              child: MouseRegion(
                onHover: (event) {
                  onNodeHover?.call(entry.key, event.position);
                },
                onExit: (_) => onNodeHoverEnd?.call(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onNodeTap?.call(entry.key),
                  onLongPressStart: (_) => onNodeDragStart?.call(entry.key),
                  onLongPressMoveUpdate: (details) {
                    onNodeDragUpdate?.call(entry.key, details.globalPosition);
                  },
                  onLongPressEnd: (_) => onNodeDragEnd?.call(),
                  child: _TaxiwayPlanPoint(
                    index: entry.key + 1,
                    scale: scale,
                    isSelected: selectedIndex == entry.key,
                    isDragging: draggingIndex == entry.key,
                    color: _resolveNodeColor(
                      entry.value.colorHex,
                      isCompleted: completedNodeIndexes.contains(entry.key),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TaxiwayPlanPoint extends StatefulWidget {
  final int index;
  final double scale;
  final bool isSelected;
  final bool isDragging;
  final Color color;

  const _TaxiwayPlanPoint({
    required this.index,
    required this.scale,
    required this.isSelected,
    required this.isDragging,
    required this.color,
  });

  @override
  State<_TaxiwayPlanPoint> createState() => _TaxiwayPlanPointState();
}

class _TaxiwayPlanPointState extends State<_TaxiwayPlanPoint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 880),
      lowerBound: 0,
      upperBound: 1,
    );
    if (widget.isDragging) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _TaxiwayPlanPoint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDragging == oldWidget.isDragging) {
      return;
    }
    if (widget.isDragging) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = widget.isDragging
            ? 1 + _pulseController.value * 0.12
            : 1.0;
        final liftY = widget.isDragging ? -8 * widget.scale : 0.0;
        return Transform.translate(
          offset: Offset(0, liftY),
          child: Transform.scale(scale: pulseValue, child: child),
        );
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.isSelected || widget.isDragging
                ? Colors.white
                : Colors.black.withValues(alpha: 0.75),
            width: widget.isSelected || widget.isDragging
                ? 2.5 * widget.scale
                : 1.0,
          ),
          boxShadow: widget.isDragging
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.75),
                    blurRadius: 18 * widget.scale,
                    spreadRadius: 2.5 * widget.scale,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 12 * widget.scale,
                    offset: Offset(0, 7 * widget.scale),
                  ),
                ]
              : null,
        ),
        child: Text(
          '${widget.index}',
          style: TextStyle(
            color: Colors.black,
            fontSize: 9 * widget.scale,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

Color _resolveNodeColor(String? hexValue, {bool isCompleted = false}) {
  final normalized = hexValue?.trim().toUpperCase();
  Color baseColor = Colors.cyanAccent.withValues(alpha: 0.9);
  if (normalized != null && normalized.isNotEmpty) {
    final hex = normalized.startsWith('#')
        ? normalized.substring(1)
        : normalized;
    if (RegExp(r'^[0-9A-F]{6}$').hasMatch(hex)) {
      baseColor = Color(int.parse('FF$hex', radix: 16));
    } else if (RegExp(r'^[0-9A-F]{8}$').hasMatch(hex)) {
      baseColor = Color(int.parse(hex, radix: 16));
    }
  }
  if (!isCompleted) {
    return baseColor;
  }
  final muted =
      Color.lerp(baseColor, Colors.grey.shade600, 0.72) ?? Colors.grey.shade600;
  return muted.withValues(alpha: 0.58);
}

Color _resolveSegmentColor(String? hexValue, {bool isCompleted = false}) {
  final normalized = hexValue?.trim().toUpperCase();
  Color baseColor = Colors.amberAccent.withValues(alpha: 0.95);
  if (normalized != null && normalized.isNotEmpty) {
    final hex = normalized.startsWith('#')
        ? normalized.substring(1)
        : normalized;
    if (RegExp(r'^[0-9A-F]{6}$').hasMatch(hex)) {
      baseColor = Color(int.parse('FF$hex', radix: 16));
    } else if (RegExp(r'^[0-9A-F]{8}$').hasMatch(hex)) {
      baseColor = Color(int.parse(hex, radix: 16));
    }
  }
  if (!isCompleted) {
    return baseColor;
  }
  final muted =
      Color.lerp(baseColor, Colors.grey.shade600, 0.72) ?? Colors.grey.shade600;
  return muted.withValues(alpha: 0.58);
}

LatLng _segmentMidpoint(MapTaxiwayNode start, MapTaxiwayNode end) {
  return LatLng(
    (start.latitude + end.latitude) / 2,
    (start.longitude + end.longitude) / 2,
  );
}

List<LatLng> _buildSegmentPolylinePoints({
  required MapTaxiwayNode start,
  required MapTaxiwayNode end,
  required MapTaxiwaySegment segment,
}) {
  if (segment.lineType == MapTaxiwaySegmentLineType.straight) {
    return <LatLng>[
      LatLng(start.latitude, start.longitude),
      LatLng(end.latitude, end.longitude),
    ];
  }
  final startLat = start.latitude;
  final startLon = start.longitude;
  final endLat = end.latitude;
  final endLon = end.longitude;
  final deltaLat = endLat - startLat;
  final deltaLon = endLon - startLon;
  final distance = math.sqrt(deltaLat * deltaLat + deltaLon * deltaLon);
  if (distance <= 0) {
    return <LatLng>[LatLng(startLat, startLon), LatLng(endLat, endLon)];
  }
  final normalizedCurvature = segment.curvature.clamp(0.0, 1.0);
  final offsetFactor = 0.12 + normalizedCurvature * 0.45;
  final offset = distance * offsetFactor;
  final directionSign = segment.curveDirection.sign.toDouble();
  final perpLat = -deltaLon / distance;
  final perpLon = deltaLat / distance;
  final controlLat = (startLat + endLat) / 2 + perpLat * offset * directionSign;
  final controlLon = (startLon + endLon) / 2 + perpLon * offset * directionSign;
  const sampleCount = 24;
  final points = <LatLng>[];
  for (var i = 0; i <= sampleCount; i++) {
    final t = i / sampleCount;
    final oneMinusT = 1 - t;
    final lat =
        oneMinusT * oneMinusT * startLat +
        2 * oneMinusT * t * controlLat +
        t * t * endLat;
    final lon =
        oneMinusT * oneMinusT * startLon +
        2 * oneMinusT * t * controlLon +
        t * t * endLon;
    points.add(LatLng(lat, lon));
  }
  return points;
}

LatLng _segmentLabelPoint({
  required MapTaxiwayNode start,
  required MapTaxiwayNode end,
  required MapTaxiwaySegment segment,
}) {
  if (segment.lineType == MapTaxiwaySegmentLineType.straight) {
    return _segmentMidpoint(start, end);
  }
  final points = _buildSegmentPolylinePoints(
    start: start,
    end: end,
    segment: segment,
  );
  return points[points.length ~/ 2];
}
