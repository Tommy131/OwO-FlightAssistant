import '../../../common/models/common_models.dart';
import '../../localization/map_localization_keys.dart';
import '../../models/map_models.dart';

/// 告警规则组件（规则引擎类型）
///
/// 仅负责后端告警映射、用户设置过滤与垂直速率规则生成。
class MapAlertComponent {
  const MapAlertComponent({
    required this.backendAlertMessageMap,
    required this.verticalRateAlertIds,
  });

  final Map<String, String> backendAlertMessageMap;
  final Set<String> verticalRateAlertIds;

  /// 将首页飞行数据中的告警转换为地图告警列表。
  List<MapFlightAlert> evaluateFlightAlerts({
    required bool isConnected,
    required bool alertsEnabled,
    required Set<String> disabledAlertIds,
    required int climbRateWarningFpm,
    required int climbRateDangerFpm,
    required int descentRateWarningFpm,
    required int descentRateDangerFpm,
    required HomeFlightData flightData,
  }) {
    if (!isConnected || !alertsEnabled) {
      return const [];
    }
    final backendAlerts = _mapBackendAlerts(flightData.flightAlerts);
    return _applyAlertSettings(
      backendAlerts: backendAlerts,
      disabledAlertIds: disabledAlertIds,
      climbRateWarningFpm: climbRateWarningFpm,
      climbRateDangerFpm: climbRateDangerFpm,
      descentRateWarningFpm: descentRateWarningFpm,
      descentRateDangerFpm: descentRateDangerFpm,
      verticalSpeedFpm: flightData.verticalSpeed,
    );
  }

  List<MapFlightAlert> _mapBackendAlerts(List<HomeFlightAlert> alerts) {
    if (alerts.isEmpty) {
      return const [];
    }
    final next = <MapFlightAlert>[];
    final shownMessages = <String>{};
    for (final alert in alerts) {
      final message = _mapBackendAlertMessage(alert.message);
      if (message == null || !shownMessages.add(message)) {
        continue;
      }
      next.add(
        MapFlightAlert(
          id: alert.id.isNotEmpty ? alert.id : alert.message,
          level: _mapBackendAlertLevel(alert.level),
          message: message,
        ),
      );
    }
    return next;
  }

  List<MapFlightAlert> _applyAlertSettings({
    required List<MapFlightAlert> backendAlerts,
    required Set<String> disabledAlertIds,
    required int climbRateWarningFpm,
    required int climbRateDangerFpm,
    required int descentRateWarningFpm,
    required int descentRateDangerFpm,
    required double? verticalSpeedFpm,
  }) {
    final next = <MapFlightAlert>[];
    final shownMessages = <String>{};
    for (final alert in backendAlerts) {
      final normalizedId = alert.id.trim().toLowerCase();
      if (verticalRateAlertIds.contains(normalizedId)) {
        continue;
      }
      if (disabledAlertIds.contains(normalizedId)) {
        continue;
      }
      if (!shownMessages.add(alert.message)) {
        continue;
      }
      next.add(alert);
    }

    final verticalRateAlert = _buildVerticalRateAlert(
      verticalSpeedFpm: verticalSpeedFpm,
      climbRateWarningFpm: climbRateWarningFpm,
      climbRateDangerFpm: climbRateDangerFpm,
      descentRateWarningFpm: descentRateWarningFpm,
      descentRateDangerFpm: descentRateDangerFpm,
    );
    if (verticalRateAlert != null) {
      final normalizedId = verticalRateAlert.id.trim().toLowerCase();
      if (!disabledAlertIds.contains(normalizedId) &&
          shownMessages.add(verticalRateAlert.message)) {
        next.add(verticalRateAlert);
      }
    }
    return next;
  }

  MapFlightAlert? _buildVerticalRateAlert({
    required double? verticalSpeedFpm,
    required int climbRateWarningFpm,
    required int climbRateDangerFpm,
    required int descentRateWarningFpm,
    required int descentRateDangerFpm,
  }) {
    if (verticalSpeedFpm == null) {
      return null;
    }
    if (verticalSpeedFpm >= climbRateDangerFpm) {
      return const MapFlightAlert(
        id: 'climb_rate_danger',
        level: MapFlightAlertLevel.danger,
        message: MapLocalizationKeys.alertClimbRateDanger,
      );
    }
    if (verticalSpeedFpm >= climbRateWarningFpm) {
      return const MapFlightAlert(
        id: 'climb_rate_warning',
        level: MapFlightAlertLevel.warning,
        message: MapLocalizationKeys.alertClimbRateWarning,
      );
    }
    final descentRate = -verticalSpeedFpm;
    if (descentRate >= descentRateDangerFpm) {
      return const MapFlightAlert(
        id: 'descent_rate_danger',
        level: MapFlightAlertLevel.danger,
        message: MapLocalizationKeys.alertDescentRateDanger,
      );
    }
    if (descentRate >= descentRateWarningFpm) {
      return const MapFlightAlert(
        id: 'descent_rate_warning',
        level: MapFlightAlertLevel.warning,
        message: MapLocalizationKeys.alertDescentRateWarning,
      );
    }
    return null;
  }

  MapFlightAlertLevel _mapBackendAlertLevel(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'danger') return MapFlightAlertLevel.danger;
    if (value == 'warning') return MapFlightAlertLevel.warning;
    return MapFlightAlertLevel.caution;
  }

  String? _mapBackendAlertMessage(String raw) {
    final value = raw.trim().toLowerCase();
    return backendAlertMessageMap[value];
  }
}
