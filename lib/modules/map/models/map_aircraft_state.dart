import 'map_coordinate.dart';

class MapAIAircraftState {
  final String id;
  final MapCoordinate position;
  final double? altitude;
  final double? heading;
  final double? groundSpeed;
  final bool? onGround;

  const MapAIAircraftState({
    required this.id,
    required this.position,
    this.altitude,
    this.heading,
    this.groundSpeed,
    this.onGround,
  });
}

/// 飞机实时飞行状态快照
///
/// 包含飞机当前的位置、姿态、速度等关键飞行参数，
/// 由 [MapProvider] 从数据快照中组装后分发给各 UI 组件。
class MapAircraftState {
  /// 当前位置（WGS-84 经纬度）
  final MapCoordinate position;

  /// 磁航向（度，0–359，可选）
  final double? heading;

  /// 自动驾驶仪目标航向（度，可选）
  final double? headingTarget;

  /// 气压高度（英尺，可选）
  final double? altitude;

  /// 地速（节，可选）
  final double? groundSpeed;

  /// 指示空速（节，可选）
  final double? airspeed;

  /// 俯仰角（度，正值为机头上扬，可选）
  final double? pitch;

  /// 坡度/横滚角（度，正值为右倾，可选）
  final double? bank;

  /// 迎角（度，可选）
  final double? angleOfAttack;

  /// 垂直速度（英尺/分钟，正值为爬升，可选）
  final double? verticalSpeed;

  /// 失速警告是否激活（可选）
  final bool? stallWarning;

  /// 飞机是否在地面（可选）
  final bool? onGround;

  /// 停机刹车是否启用（可选）
  final bool? parkingBrake;

  const MapAircraftState({
    required this.position,
    this.heading,
    this.headingTarget,
    this.altitude,
    this.groundSpeed,
    this.airspeed,
    this.pitch,
    this.bank,
    this.angleOfAttack,
    this.verticalSpeed,
    this.stallWarning,
    this.onGround,
    this.parkingBrake,
  });
}
