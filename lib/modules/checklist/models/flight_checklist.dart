import 'package:flutter/material.dart';

enum AircraftFamily { generic, a320, b737 }

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
