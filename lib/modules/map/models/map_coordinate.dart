/// 地理坐标模型
///
/// 包含两个基础坐标类：
/// - [MapCoordinate]：经纬度坐标点（WGS-84 坐标系）
/// - [MapRoutePoint]：飞行轨迹点（继承坐标，附带高度、速度、时间戳）
library;

/// 地图坐标点（WGS-84 经纬度）
class MapCoordinate {
  /// 纬度，范围 [-90, 90]
  final double latitude;

  /// 经度，范围 [-180, 180]
  final double longitude;

  const MapCoordinate({required this.latitude, required this.longitude});
}

/// 飞行轨迹点
///
/// 继承 [MapCoordinate]，额外携带飞行参数，用于在地图上绘制历史轨迹。
class MapRoutePoint extends MapCoordinate {
  /// 高度（英尺，可选）
  final double? altitude;

  /// 地速（节，可选）
  final double? groundSpeed;

  /// 记录时间戳（可选）
  final DateTime? timestamp;

  const MapRoutePoint({
    required super.latitude,
    required super.longitude,
    this.altitude,
    this.groundSpeed,
    this.timestamp,
  });
}
