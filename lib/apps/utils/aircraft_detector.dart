import '../models/simulator_data.dart';

/// 机型检测结果
class AircraftDetectionResult {
  final String aircraftType;
  final int detectionCount;
  final bool isStable;

  const AircraftDetectionResult({
    required this.aircraftType,
    required this.detectionCount,
    required this.isStable,
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
    final flapDetents = data.flapsPosition ?? 0;

    // 如果还没有获取到关键特征数据，继续等待
    if (flapDetents == 0 && n1_1 < 0.1 && n1_2 < 0.1) {
      return null;
    }

    String detectedType = _identifyAircraftType(n1_1, n1_2, flapDetents);
    if (detectedType == 'Unknown') {
      return null;
    }

    // 防抖逻辑：必须连续多帧识别到同一机型
    if (detectedType == _lastPendingAircraft) {
      _detectionCount++;
    } else {
      _lastPendingAircraft = detectedType;
      _detectionCount = 1;
      return AircraftDetectionResult(
        aircraftType: detectedType,
        detectionCount: _detectionCount,
        isStable: false,
      );
    }

    return AircraftDetectionResult(
      aircraftType: detectedType,
      detectionCount: _detectionCount,
      isStable: _detectionCount >= _requiredDetectionFrames,
    );
  }

  /// 识别机型类型
  String _identifyAircraftType(double n1_1, double n1_2, int flapDetents) {
    final isJet = n1_1 > 5 || n1_2 > 5 || flapDetents >= 5;

    if (isJet) {
      if (flapDetents >= 8) {
        return 'Boeing 737';
      } else if (flapDetents > 0) {
        return 'Airbus A320';
      } else {
        // 如果是喷气机但还没收到襟翼档位数据，先不急着下结论
        return 'Unknown';
      }
    } else if (flapDetents > 0) {
      return 'General Aviation Aircraft';
    } else {
      return 'Unknown';
    }
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
