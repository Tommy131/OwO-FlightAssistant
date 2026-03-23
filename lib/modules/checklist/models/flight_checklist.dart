import 'package:flutter/material.dart';

/// 飞机机型家族枚举
enum AircraftFamily { generic, a320, b737 }

/// 检查单飞行阶段枚举
/// 每个阶段对应一个本地化 key 和侧边栏图标
enum ChecklistPhase {
  coldAndDark('checklist.phase.cold_and_dark', Icons.power_settings_new),
  beforePushback('checklist.phase.before_pushback', Icons.airport_shuttle),
  beforeTaxi('checklist.phase.before_taxi', Icons.directions),
  beforeTakeoff('checklist.phase.before_takeoff', Icons.flight_takeoff),
  cruise('checklist.phase.cruise', Icons.flight),
  beforeDescent('checklist.phase.before_descent', Icons.trending_down),
  beforeApproach('checklist.phase.before_approach', Icons.radar),
  afterLanding('checklist.phase.after_landing', Icons.flight_land),
  parking('checklist.phase.parking', Icons.local_parking);

  final String labelKey;
  final IconData icon;
  const ChecklistPhase(this.labelKey, this.icon);
}

/// 单条检查单条目
class ChecklistItem {
  final String id;

  /// 需要执行的操作/任务
  final String task;

  /// 标准响应（期望状态）
  final String response;

  /// 是否已勾选完成
  bool isChecked;

  /// 可选的补充说明
  final String? detail;

  ChecklistItem({
    required this.id,
    required this.task,
    required this.response,
    this.isChecked = false,
    this.detail,
  });
}

/// 检查单节段（对应单个飞行阶段）
class ChecklistSection {
  final ChecklistPhase phase;
  final List<ChecklistItem> items;

  ChecklistSection({required this.phase, required this.items});
}

/// 单机型检查单（包含全部飞行阶段的节段）
class AircraftChecklist {
  final String id;
  final String name;
  final AircraftFamily family;
  final List<ChecklistSection> sections;

  AircraftChecklist({
    required this.id,
    required this.name,
    required this.family,
    required this.sections,
  });
}
