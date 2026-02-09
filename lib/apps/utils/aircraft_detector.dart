import '../data/aircraft_catalog.dart';
import '../models/simulator_data.dart';

/// 机型检测结果
class AircraftDetectionResult {
  final String aircraftType;
  final int detectionCount;
  final bool isStable;
  final AircraftIdentity? identity;

  const AircraftDetectionResult({
    required this.aircraftType,
    required this.detectionCount,
    required this.isStable,
    this.identity,
  });
}

/// 机型智能检测器
///
/// 通过分析飞机的关键特征参数（如N1值、襟翼档位等）来识别机型
/// 使用防抖机制确保检测结果稳定
class AircraftDetector {
  static const int _requiredDetectionFrames = 5; // 需要连续5帧一致

  String? _lastPendingAircraft;
  int _detectionCount = 0;

  /// 根据模拟器数据检测机型
  ///
  /// 返回检测结果，包含机型名称和稳定性信息
  AircraftDetectionResult? detectAircraft(SimulatorData data) {
    final n1_1 = data.engine1N1 ?? 0;
    final n1_2 = data.engine2N1 ?? 0;
    final flapDetents = data.flapDetentsCount ?? 0;
    final title = data.aircraftTitle;

    if (flapDetents == 0 && n1_1 < 0.1 && n1_2 < 0.1 && title == null) {
      return null;
    }

    // 1. 尝试精确匹配 (关键字/ICAO等)
    final match = AircraftCatalog.match(
      title: title,
      engineCount: data.numEngines,
      flapDetents: flapDetents,
      wingArea: data.wingArea,
    );

    // 2. 如果没匹配到，尝试结构化匹配兜底
    final identity =
        match?.identity ??
        AircraftCatalog.matchByStructural(
          engineCount: data.numEngines,
          flapDetents: flapDetents,
          n1_1: n1_1,
          n1_2: n1_2,
        );

    if (identity == null) return null;

    final detectedType = identity.displayName;

    // 防抖逻辑：必须连续多帧识别到同一机型 (以 displayName 为准)
    if (detectedType == _lastPendingAircraft) {
      _detectionCount++;
    } else {
      _lastPendingAircraft = detectedType;
      _detectionCount = 1;
      return AircraftDetectionResult(
        aircraftType: detectedType,
        detectionCount: _detectionCount,
        isStable: false,
        identity: identity,
      );
    }

    return AircraftDetectionResult(
      aircraftType: detectedType,
      detectionCount: _detectionCount,
      isStable: _detectionCount >= _requiredDetectionFrames,
      identity: identity,
    );
  }

  /// 重置检测器状态
  void reset() {
    _lastPendingAircraft = null;
    _detectionCount = 0;
  }

  /// 获取当前检测进度（0.0 ~ 1.0）
  double get detectionProgress {
    if (_detectionCount == 0) return 0.0;
    return (_detectionCount / _requiredDetectionFrames).clamp(0.0, 1.0);
  }

  /// 是否已稳定识别
  bool get isStable => _detectionCount >= _requiredDetectionFrames;
}
