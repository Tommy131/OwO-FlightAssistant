import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../models/map_coordinate.dart';

/// 地图几何工具类
///
/// 封装地图模块所需的纯几何计算函数，全部以静态方法提供，
/// 不持有任何状态，可在 [MapProvider] 及测试场景中直接调用。
///
/// 包含：
/// - 坐标合法性校验
/// - 球面距离计算（米）
/// - 投影与跑道横侧偏差计算
class MapGeoUtils {
  MapGeoUtils._(); // 纯工具类，禁止实例化

  // ── 坐标校验 ──────────────────────────────────────────────────────────────

  /// 判断经纬度坐标是否合法
  ///
  /// 合法条件（全部满足）：
  /// 1. 纬度在 [-90, 90] 范围内
  /// 2. 经度在 [-180, 180] 范围内
  /// 3. 纬度或经度绝对值 ≥ 0.0001（排除 (0, 0) 空坐标）
  static bool isValidCoordinate(double latitude, double longitude) {
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    if (latitude.abs() < 0.0001 && longitude.abs() < 0.0001) return false;
    return true;
  }

  // ── 距离计算 ──────────────────────────────────────────────────────────────

  /// 计算两点之间的球面距离（米）
  ///
  /// 基于 [LatLng] 和 [Distance] 实现，精度适合航空场景。
  static double distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return const Distance().as(
      LengthUnit.Meter,
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    );
  }

  // ── 投影计算 ──────────────────────────────────────────────────────────────

  /// 计算点到跑道中心线的投影关系
  ///
  /// 返回 [MapRunwayProjection]，包含：
  /// - [MapRunwayProjection.alongTrackRatio]：点在跑道方向上的投影比例
  ///   （0 = 跑道起点，1 = 跑道终点，<0 或 >1 代表超出跑道范围）
  /// - [MapRunwayProjection.crossTrackDistanceM]：点到跑道中心线的侧向距离（米）
  static MapRunwayProjection projectPointToRunway({
    required MapCoordinate point,
    required MapCoordinate runwayStart,
    required MapCoordinate runwayEnd,
  }) {
    final start = _projectToMeters(
      latitude: runwayStart.latitude,
      longitude: runwayStart.longitude,
      refLatitude: runwayStart.latitude,
      refLongitude: runwayStart.longitude,
    );
    final end = _projectToMeters(
      latitude: runwayEnd.latitude,
      longitude: runwayEnd.longitude,
      refLatitude: runwayStart.latitude,
      refLongitude: runwayStart.longitude,
    );
    final target = _projectToMeters(
      latitude: point.latitude,
      longitude: point.longitude,
      refLatitude: runwayStart.latitude,
      refLongitude: runwayStart.longitude,
    );

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final lenSq = dx * dx + dy * dy;
    if (lenSq <= 0) {
      return const MapRunwayProjection(
        alongTrackRatio: 0,
        crossTrackDistanceM: 999999,
      );
    }

    final ratio =
        ((target.dx - start.dx) * dx + (target.dy - start.dy) * dy) / lenSq;
    final closestX = start.dx + ratio * dx;
    final closestY = start.dy + ratio * dy;
    final crossTrack = math.sqrt(
      (target.dx - closestX) * (target.dx - closestX) +
          (target.dy - closestY) * (target.dy - closestY),
    );
    return MapRunwayProjection(
      alongTrackRatio: ratio,
      crossTrackDistanceM: crossTrack,
    );
  }

  /// 将经纬度坐标投影到以 [refLatitude]/[refLongitude] 为原点的平面坐标系（单位：米）
  ///
  /// 使用等效距离近似：
  /// - Y 轴：1° 纬度 ≈ 111320 米
  /// - X 轴：1° 经度 ≈ 111320 × cos(纬度) 米
  static _ProjectedPoint _projectToMeters({
    required double latitude,
    required double longitude,
    required double refLatitude,
    required double refLongitude,
  }) {
    const meterPerDegLat = 111320.0;
    final meterPerDegLon =
        meterPerDegLat * math.cos(refLatitude * math.pi / 180);
    return _ProjectedPoint(
      dx: (longitude - refLongitude) * meterPerDegLon,
      dy: (latitude - refLatitude) * meterPerDegLat,
    );
  }
}

// ── 内部数据类 ───────────────────────────────────────────────────────────────

/// 平面投影坐标（用于本文件内部的几何计算，以米为单位）
class _ProjectedPoint {
  final double dx;
  final double dy;
  const _ProjectedPoint({required this.dx, required this.dy});
}

/// 跑道投影结果
///
/// 描述某坐标点与跑道中心线的空间关系。
class MapRunwayProjection {
  /// 沿跑道方向的投影比例（0 = 起点，1 = 终点）
  final double alongTrackRatio;

  /// 到跑道中心线的侧向距离（米，始终为正数）
  final double crossTrackDistanceM;

  const MapRunwayProjection({
    required this.alongTrackRatio,
    required this.crossTrackDistanceM,
  });
}
