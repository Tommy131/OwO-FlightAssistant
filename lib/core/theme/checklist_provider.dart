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
    _selectedAircraft = _aircraftList.firstWhere((a) => a.id == id);
    _currentPhase = ChecklistPhase.coldAndDark;
    notifyListeners();
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
    final section = _selectedAircraft!.sections.firstWhere(
      (s) => s.phase == _currentPhase,
    );
    for (var item in section.items) {
      item.isChecked = false;
    }
    notifyListeners();
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
