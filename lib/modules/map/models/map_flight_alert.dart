/// 飞行警报模型
///
/// 定义警报等级枚举和警报数据类，由 [MapProvider] 实时计算后推送给 UI。
library;

/// 飞行警报等级
///
/// 按严重程度从低到高排列：[caution] < [warning] < [danger]
enum MapFlightAlertLevel {
  /// 注意（蓝色/青色提示，不影响飞行安全但需留意）
  caution,

  /// 警告（橙色提示，可能影响飞行安全）
  warning,

  /// 危险（红色或闪烁提示，需立即处置）
  danger,
}

/// 单条飞行警报
///
/// 由后端告警或本地垂直速率计算产生，[MapProvider] 合并去重后
/// 以列表形式暴露给地图 HUD 和弹窗组件。
class MapFlightAlert {
  /// 警报唯一标识符（如 "pitch_up_danger"、"climb_rate_warning"）
  final String id;

  /// 警报等级（[MapFlightAlertLevel.caution/warning/danger]）
  final MapFlightAlertLevel level;

  /// 本地化键名（通过 `.tr(context)` 获取可读描述）
  final String message;

  const MapFlightAlert({
    required this.id,
    required this.level,
    required this.message,
  });
}
