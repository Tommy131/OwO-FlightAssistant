import '../models/flight_checklist.dart';

/// 检查单序列化器
/// 负责将内存中的 [AircraftChecklist] 对象列表转换为可持久化的 JSON 格式
class ChecklistSerializer {
  /// 将多个 [AircraftChecklist] 序列化为标准 JSON Map
  /// 格式：`{ "version": 1, "aircraft": [...] }`
  Map<String, dynamic> serialize(List<AircraftChecklist> aircraft) {
    return {
      'version': 1,
      'aircraft': aircraft.map(_serializeAircraft).toList(),
    };
  }

  /// 序列化单个机型
  Map<String, dynamic> _serializeAircraft(AircraftChecklist aircraft) {
    return {
      'id': aircraft.id,
      'name': aircraft.name,
      'family': aircraft.family.name,
      'sections': aircraft.sections.map(_serializeSection).toList(),
    };
  }

  /// 序列化单个阶段节段
  Map<String, dynamic> _serializeSection(ChecklistSection section) {
    return {
      'phase': section.phase.name,
      'items': section.items.map(_serializeItem).toList(),
    };
  }

  /// 序列化单个检查单条目，[detail] 字段为空时不写入
  Map<String, dynamic> _serializeItem(ChecklistItem item) {
    return {
      'id': item.id,
      'task': item.task,
      'response': item.response,
      if (item.detail != null) 'detail': item.detail,
    };
  }
}
