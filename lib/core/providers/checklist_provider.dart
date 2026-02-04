import 'package:flutter/material.dart';

import '../models/flight_checklist.dart';
import '../services/checklist_service.dart';

class ChecklistProvider with ChangeNotifier {
  final ChecklistService _service = ChecklistService();

  List<AircraftChecklist> _aircraftList = [];
  AircraftChecklist? _selectedAircraft;
  ChecklistPhase _currentPhase = ChecklistPhase.coldAndDark;

  List<AircraftChecklist> get aircraftList => _aircraftList;
  AircraftChecklist? get selectedAircraft => _selectedAircraft;
  ChecklistPhase get currentPhase => _currentPhase;

  ChecklistProvider() {
    _init();
  }

  void _init() {
    _aircraftList = _service.getSupportedAircraft();
    if (_aircraftList.isNotEmpty) {
      _selectedAircraft = _aircraftList.first;
    }
    notifyListeners();
  }

  void selectAircraft(String id) {
    try {
      final aircraft = _aircraftList.firstWhere((a) => a.id == id);
      _selectedAircraft = aircraft;
      _currentPhase = ChecklistPhase.coldAndDark;
      notifyListeners();
    } catch (e) {
      // 机型未找到，保持当前选择
      debugPrint(
        '未找到机型: $id，可用机型: ${_aircraftList.map((a) => a.id).join(", ")}',
      );
    }
  }

  void setPhase(ChecklistPhase phase) {
    _currentPhase = phase;
    notifyListeners();
  }

  void toggleItem(String itemId) {
    if (_selectedAircraft == null) return;

    for (var section in _selectedAircraft!.sections) {
      for (var item in section.items) {
        if (item.id == itemId) {
          item.isChecked = !item.isChecked;
          notifyListeners();
          return;
        }
      }
    }
  }

  void resetCurrentPhase() {
    if (_selectedAircraft == null) return;
    try {
      final section = _selectedAircraft!.sections.firstWhere(
        (s) => s.phase == _currentPhase,
      );
      for (var item in section.items) {
        item.isChecked = false;
      }
      notifyListeners();
    } catch (e) {
      // Phase not found for this aircraft
    }
  }

  void resetAll() {
    if (_selectedAircraft == null) return;
    for (var section in _selectedAircraft!.sections) {
      for (var item in section.items) {
        item.isChecked = false;
      }
    }
    _currentPhase = ChecklistPhase.coldAndDark;
    notifyListeners();
  }

  double getPhaseProgress(ChecklistPhase phase) {
    if (_selectedAircraft == null) return 0;
    try {
      final section = _selectedAircraft!.sections.firstWhere(
        (s) => s.phase == phase,
      );
      if (section.items.isEmpty) return 1.0;
      final checkedCount = section.items.where((i) => i.isChecked).length;
      return checkedCount / section.items.length;
    } catch (e) {
      return 0.0;
    }
  }
}
