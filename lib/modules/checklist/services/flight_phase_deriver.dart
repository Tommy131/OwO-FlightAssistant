import '../../common/models/common_models.dart';
import '../models/flight_checklist.dart';

/// 飞行阶段推导器
/// 根据实时飞行数据或后端阶段字符串推导当前所处的检查单 [ChecklistPhase]
class FlightPhaseDeriver {
  /// 从 [FlightData] 推导当前飞行阶段
  ///
  /// 推导优先级：
  ///   1. 后端明确返回的 `flightPhase` 字段（枚举映射）
  ///   2. 基于高度、垂直速度、地速、停机刹车等飞行参数推算
  ChecklistPhase? derive(FlightData flightData) {
    // 优先使用后端明确的飞行阶段
    final phaseFromBackend = _mapBackendPhase(flightData.flightPhase);
    if (phaseFromBackend != null) return phaseFromBackend;

    final onGround = flightData.onGround;
    if (onGround == null) return null;

    final groundSpeed = flightData.groundSpeed ?? 0;
    final altitude = flightData.altitude ?? 0;
    final verticalSpeed = flightData.verticalSpeed ?? 0;
    final parkingBrake = flightData.parkingBrake ?? false;
    final engineRunning =
        (flightData.engine1Running ?? false) ||
        (flightData.engine2Running ?? false);

    if (!onGround) {
      // 空中阶段判断
      if (altitude <= 5000 && verticalSpeed <= -500) {
        return ChecklistPhase.beforeApproach;
      }
      if (verticalSpeed <= -700 && altitude > 5000) {
        return ChecklistPhase.beforeDescent;
      }
      return ChecklistPhase.cruise;
    }

    // 地面阶段判断（按地速从高到低区分）
    if (groundSpeed >= 45) return ChecklistPhase.afterLanding;
    if (groundSpeed >= 8) return ChecklistPhase.beforeTaxi;
    if (!parkingBrake && engineRunning) return ChecklistPhase.beforePushback;
    if (parkingBrake && engineRunning) return ChecklistPhase.beforeTakeoff;
    if (parkingBrake && !engineRunning) return ChecklistPhase.coldAndDark;

    return ChecklistPhase.parking;
  }

  /// 判断是否应该自动切换飞行阶段
  ///
  /// 规则：只允许阶段前进，但着陆后、停机、冷舱等阶段可以倒退（航班循环）
  bool shouldApply({
    required ChecklistPhase current,
    required ChecklistPhase next,
  }) {
    final currentIndex = ChecklistPhase.values.indexOf(current);
    final nextIndex = ChecklistPhase.values.indexOf(next);
    if (nextIndex >= currentIndex) return true;
    // 允许倒退的特定阶段（落地后/停机/冷舱，对应新一段飞行）
    return next == ChecklistPhase.afterLanding ||
        next == ChecklistPhase.parking ||
        next == ChecklistPhase.coldAndDark;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 后端阶段字符串映射
  // ──────────────────────────────────────────────────────────────────────────

  /// 将后端返回的飞行阶段字符串映射为 [ChecklistPhase]
  ChecklistPhase? _mapBackendPhase(String? phase) {
    switch ((phase ?? '').trim().toLowerCase()) {
      case 'taxi':
        return ChecklistPhase.beforeTaxi;
      case 'takeoff':
        return ChecklistPhase.beforeTakeoff;
      case 'climb':
      case 'cruise':
        return ChecklistPhase.cruise;
      case 'approach':
        return ChecklistPhase.beforeApproach;
      case 'landing':
        return ChecklistPhase.afterLanding;
      default:
        return null;
    }
  }
}
