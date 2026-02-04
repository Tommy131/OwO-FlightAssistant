import 'package:flutter/material.dart';

enum AircraftFamily { a320, b737 }

enum ChecklistPhase {
  coldAndDark('冷舱启动', Icons.power_settings_new), // 电源图标
  beforePushback('推出前', Icons.airport_shuttle), // 推出车图标
  beforeTaxi('滑行前', Icons.directions), // 方向图标
  beforeTakeoff('起飞前', Icons.flight_takeoff), // 起飞图标
  cruise('巡航', Icons.flight), // 飞行图标
  beforeDescent('下降前', Icons.trending_down), // 下降图标
  beforeApproach('进近前', Icons.radar), // 雷达图标
  afterLanding('落地后', Icons.flight_land), // 降落图标
  parking('关车/停机', Icons.local_parking); // 停车图标

  final String label;
  final IconData icon;
  const ChecklistPhase(this.label, this.icon);
}

class ChecklistItem {
  final String id;
  final String task;
  final String response;
  bool isChecked;
  final String? detail;

  ChecklistItem({
    required this.id,
    required this.task,
    required this.response,
    this.isChecked = false,
    this.detail,
  });
}

class ChecklistSection {
  final ChecklistPhase phase;
  final List<ChecklistItem> items;

  ChecklistSection({required this.phase, required this.items});
}

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
