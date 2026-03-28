import '../models/flight_checklist.dart';
import '../data/a320_checklist.dart';
import '../data/b737_checklist.dart';
import '../data/generic_checklist.dart';
import '../localization/checklist_localization_keys.dart';
import '../../../core/services/localization_service.dart';

/// 机型解析器
/// 负责根据飞行数据中的机型标识符，从已加载的检查单列表中匹配最合适的机型
class AircraftResolver {
  /// 从机型列表中根据标识符字符串匹配最佳机型
  ///
  /// 匹配优先级：
  ///   1. ID / 名称精确包含
  ///   2. 机型家族模糊识别（B737 / A320）
  ///   3. 通用机型 (generic)
  ///   4. 列表第一项（兜底）
  AircraftChecklist? resolve({
    required String? identifier,
    required List<AircraftChecklist> aircraftList,
  }) {
    if (aircraftList.isEmpty) return null;
    final normalized = (identifier ?? '').trim().toLowerCase();

    if (normalized.isEmpty) {
      return _findGeneric(aircraftList) ?? aircraftList.first;
    }

    // 尝试 ID 或名称精确包含匹配
    for (final aircraft in aircraftList) {
      final id = aircraft.id.toLowerCase();
      final name = aircraft.name.toLowerCase();
      if (normalized.contains(id) || normalized.contains(name)) {
        return aircraft;
      }
    }

    // 模糊家族匹配
    if (_looksLikeB737(normalized)) {
      return _findByFamily(AircraftFamily.b737, aircraftList) ??
          _findGeneric(aircraftList) ??
          aircraftList.first;
    }
    if (_looksLikeA320(normalized)) {
      return _findByFamily(AircraftFamily.a320, aircraftList) ??
          _findGeneric(aircraftList) ??
          aircraftList.first;
    }

    return _findGeneric(aircraftList) ?? aircraftList.first;
  }

  /// 根据种子字符串推断机型家族（用于导入时自动归类）
  AircraftFamily inferFamily({required String seed}) {
    final n = seed.toLowerCase();
    if (n.contains('737') || n.contains('b738')) return AircraftFamily.b737;
    if (n.contains('320') ||
        n.contains('321') ||
        n.contains('319') ||
        n.contains('a32')) {
      return AircraftFamily.a320;
    }
    return AircraftFamily.generic;
  }

  /// 返回所有内建预置检查单列表
  List<AircraftChecklist> getBuiltInChecklists() {
    final t = LocalizationService().translate;
    return [
      GenericChecklist.create(
        t(ChecklistLocalizationKeys.builtInGenericAircraft),
      ),
      A320Checklist.create('A320-200 / A321 / A319'),
      B737Checklist.create('B737-800 / Max'),
    ];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 私有辅助方法
  // ──────────────────────────────────────────────────────────────────────────

  bool _looksLikeA320(String text) =>
      text.contains('a320') ||
      text.contains('a319') ||
      text.contains('a321') ||
      text.contains('a32n') ||
      text.contains('airbus a3');

  bool _looksLikeB737(String text) =>
      text.contains('b737') ||
      text.contains('737') ||
      text.contains('b738') ||
      text.contains('zibo') ||
      text.contains('boeing 737');

  AircraftChecklist? _findByFamily(
    AircraftFamily family,
    List<AircraftChecklist> list,
  ) {
    for (final aircraft in list) {
      if (aircraft.family == family) return aircraft;
    }
    return null;
  }

  AircraftChecklist? _findGeneric(List<AircraftChecklist> list) {
    for (final aircraft in list) {
      if (aircraft.family == AircraftFamily.generic ||
          aircraft.id.toLowerCase() == 'generic') {
        return aircraft;
      }
    }
    return null;
  }
}
