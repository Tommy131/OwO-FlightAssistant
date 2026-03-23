import 'package:latlong2/latlong.dart';
import '../map_geo_utils.dart';
import '../../models/map_models.dart';

/// 轨迹计算组件（算法类型）
///
/// 仅处理移动判定、轨迹追加和起降点状态流转，不依赖 UI。
class MapFlightTrackComponent {
  MapFlightTrackComponent._();

  /// 结合速度与位置采样判断飞机是否在移动。
  static MapFlightMovementResult resolveAircraftMoving({
    required bool isConnected,
    required bool isPaused,
    required MapAircraftState aircraftState,
    required DateTime now,
    required MapCoordinate? lastSamplePosition,
    required DateTime? lastSampleAt,
  }) {
    if (!isConnected || isPaused) {
      return MapFlightMovementResult(
        isMoving: false,
        nextSamplePosition: aircraftState.position,
        nextSampleAt: now,
      );
    }
    final speed = aircraftState.groundSpeed ?? 0;
    final movingBySpeed = speed >= 1.5;
    var movingByDistance = false;
    if (lastSamplePosition != null && lastSampleAt != null) {
      final movedDistance = const Distance().as(
        LengthUnit.Meter,
        LatLng(lastSamplePosition.latitude, lastSamplePosition.longitude),
        LatLng(
          aircraftState.position.latitude,
          aircraftState.position.longitude,
        ),
      );
      final elapsedMs = now.difference(lastSampleAt).inMilliseconds;
      movingByDistance = elapsedMs >= 350 && movedDistance >= 2.5;
    }
    return MapFlightMovementResult(
      isMoving: movingBySpeed || movingByDistance,
      nextSamplePosition: aircraftState.position,
      nextSampleAt: now,
    );
  }

  /// 在满足位移阈值时追加轨迹点，并控制轨迹长度上限。
  static MapFlightRouteAppendResult appendRoutePoint({
    required List<MapRoutePoint> route,
    required DateTime? lastRouteTimestamp,
    required MapAircraftState aircraftState,
    required DateTime now,
    required bool isMoving,
  }) {
    if (!isMoving) {
      return MapFlightRouteAppendResult(
        route: route,
        lastRouteTimestamp: lastRouteTimestamp,
      );
    }
    if (route.isNotEmpty) {
      final last = route.last;
      final movedDistance = const Distance().as(
        LengthUnit.Meter,
        LatLng(last.latitude, last.longitude),
        LatLng(
          aircraftState.position.latitude,
          aircraftState.position.longitude,
        ),
      );
      final secondsFromLast = lastRouteTimestamp == null
          ? 999
          : now.difference(lastRouteTimestamp).inSeconds;
      if (movedDistance < 6 && secondsFromLast < 2) {
        return MapFlightRouteAppendResult(
          route: route,
          lastRouteTimestamp: lastRouteTimestamp,
        );
      }
    }
    var nextRoute = <MapRoutePoint>[
      ...route,
      MapRoutePoint(
        latitude: aircraftState.position.latitude,
        longitude: aircraftState.position.longitude,
        altitude: aircraftState.altitude,
        groundSpeed: aircraftState.groundSpeed,
        timestamp: now,
      ),
    ];
    if (nextRoute.length > 3600) {
      nextRoute = nextRoute.sublist(nextRoute.length - 3600);
    }
    return MapFlightRouteAppendResult(
      route: nextRoute,
      lastRouteTimestamp: now,
    );
  }

  /// 根据接地状态边沿变化维护起飞点与落地点。
  static MapTakeoffLandingMarkerResult updateTakeoffLandingMarker({
    required bool? onGround,
    required MapCoordinate position,
    required bool? lastOnGround,
    required MapCoordinate? takeoffPoint,
    required MapCoordinate? landingPoint,
  }) {
    if (onGround == null) {
      return MapTakeoffLandingMarkerResult(
        lastOnGround: lastOnGround,
        takeoffPoint: takeoffPoint,
        landingPoint: landingPoint,
      );
    }
    if (lastOnGround == null) {
      return MapTakeoffLandingMarkerResult(
        lastOnGround: onGround,
        takeoffPoint: takeoffPoint,
        landingPoint: landingPoint,
      );
    }
    var nextTakeoff = takeoffPoint;
    var nextLanding = landingPoint;
    if (lastOnGround && !onGround) {
      nextTakeoff = position;
    } else if (!lastOnGround && onGround) {
      nextLanding = position;
    }
    return MapTakeoffLandingMarkerResult(
      lastOnGround: onGround,
      takeoffPoint: nextTakeoff,
      landingPoint: nextLanding,
    );
  }

  /// 跑道近邻判定，供自动计时器启动条件复用。
  static bool isNearRunwayOrEndpoint({
    required MapAircraftState aircraftState,
    required List<MapRunwayGeometry> runways,
  }) {
    if (runways.isEmpty) {
      return false;
    }
    for (final runway in runways) {
      final lengthM =
          runway.lengthM ??
          MapGeoUtils.distanceMeters(
            runway.start.latitude,
            runway.start.longitude,
            runway.end.latitude,
            runway.end.longitude,
          );
      if (lengthM <= 0) {
        continue;
      }
      final projection = MapGeoUtils.projectPointToRunway(
        point: aircraftState.position,
        runwayStart: runway.start,
        runwayEnd: runway.end,
      );
      final lateralDistance = projection.crossTrackDistanceM.abs();
      final nearCenterLine =
          projection.alongTrackRatio >= -0.1 &&
          projection.alongTrackRatio <= 1.1 &&
          lateralDistance <= 95;
      final distanceToStart = MapGeoUtils.distanceMeters(
        aircraftState.position.latitude,
        aircraftState.position.longitude,
        runway.start.latitude,
        runway.start.longitude,
      );
      final distanceToEnd = MapGeoUtils.distanceMeters(
        aircraftState.position.latitude,
        aircraftState.position.longitude,
        runway.end.latitude,
        runway.end.longitude,
      );
      final nearEndpoint = distanceToStart <= 220 || distanceToEnd <= 220;
      if (nearCenterLine || nearEndpoint) {
        return true;
      }
    }
    return false;
  }
}

class MapFlightMovementResult {
  const MapFlightMovementResult({
    required this.isMoving,
    required this.nextSamplePosition,
    required this.nextSampleAt,
  });

  final bool isMoving;
  final MapCoordinate nextSamplePosition;
  final DateTime nextSampleAt;
}

class MapFlightRouteAppendResult {
  const MapFlightRouteAppendResult({
    required this.route,
    required this.lastRouteTimestamp,
  });

  final List<MapRoutePoint> route;
  final DateTime? lastRouteTimestamp;
}

class MapTakeoffLandingMarkerResult {
  const MapTakeoffLandingMarkerResult({
    required this.lastOnGround,
    required this.takeoffPoint,
    required this.landingPoint,
  });

  final bool? lastOnGround;
  final MapCoordinate? takeoffPoint;
  final MapCoordinate? landingPoint;
}
