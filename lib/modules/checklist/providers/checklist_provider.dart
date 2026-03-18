import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../home/models/home_models.dart';
import '../models/flight_checklist.dart';
import '../services/checklist_service.dart';

class ChecklistProvider with ChangeNotifier {
  final ChecklistService _service = ChecklistService();

  List<AircraftChecklist> _aircraftList = [];
  AircraftChecklist? _selectedAircraft;
  ChecklistPhase _currentPhase = ChecklistPhase.coldAndDark;
  bool _isLoading = false;
  String? _pendingIdentifier;

  List<AircraftChecklist> get aircraftList => _aircraftList;
  AircraftChecklist? get selectedAircraft => _selectedAircraft;
  ChecklistPhase get currentPhase => _currentPhase;
  bool get isLoading => _isLoading;

  ChecklistProvider() {
    _init();
  }

  Future<void> _init() async {
    await reloadFromDirectory(fallbackToBuiltIn: true);
    updateAircraftByIdentifier(_pendingIdentifier);
  }

  void selectAircraft(String id) {
    for (final aircraft in _aircraftList) {
      if (aircraft.id == id) {
        _selectedAircraft = aircraft;
        _currentPhase = ChecklistPhase.coldAndDark;
        notifyListeners();
        return;
      }
    }
  }

  void setPhase(ChecklistPhase phase) {
    _currentPhase = phase;
    notifyListeners();
  }

  void toggleItem(String itemId) {
    if (_selectedAircraft == null) return;

    for (final section in _selectedAircraft!.sections) {
      for (final item in section.items) {
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
    ChecklistSection? targetSection;
    for (final section in _selectedAircraft!.sections) {
      if (section.phase == _currentPhase) {
        targetSection = section;
        break;
      }
    }
    if (targetSection == null) return;
    for (final item in targetSection.items) {
      item.isChecked = false;
    }
    notifyListeners();
  }

  void resetAll() {
    if (_selectedAircraft == null) return;
    for (final section in _selectedAircraft!.sections) {
      for (final item in section.items) {
        item.isChecked = false;
      }
    }
    _currentPhase = ChecklistPhase.coldAndDark;
    notifyListeners();
  }

  double getPhaseProgress(ChecklistPhase phase) {
    if (_selectedAircraft == null) return 0;
    ChecklistSection? targetSection;
    for (final section in _selectedAircraft!.sections) {
      if (section.phase == phase) {
        targetSection = section;
        break;
      }
    }
    if (targetSection == null) return 0.0;
    if (targetSection.items.isEmpty) return 1.0;
    final checkedCount = targetSection.items.where((i) => i.isChecked).length;
    return checkedCount / targetSection.items.length;
  }

  Future<int> reloadFromDirectory({bool fallbackToBuiltIn = true}) async {
    _isLoading = true;
    _selectedAircraft = null;
    notifyListeners();
    final loaded = await _service.loadFromDirectory();
    if (loaded.isEmpty && fallbackToBuiltIn) {
      _applyAircraftList(_service.getBuiltInChecklists());
      _isLoading = false;
      notifyListeners();
      return 0;
    }
    if (loaded.isNotEmpty) {
      _applyAircraftList(loaded);
    }
    _isLoading = false;
    updateAircraftByIdentifier(_pendingIdentifier);
    notifyListeners();
    return loaded.length;
  }

  Future<int> importFromFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final filePath = result?.files.single.path;
    if (filePath == null) return -1;
    final loaded = await _service.loadFromFile(File(filePath));
    if (loaded.isEmpty) return 0;
    _applyAircraftList(loaded);
    notifyListeners();
    return loaded.length;
  }

  Future<int> exportToFilePicker() async {
    if (_aircraftList.isEmpty) return -1;
    final filePath = await FilePicker.platform.saveFile(
      fileName: 'checklist_export.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (filePath == null) return 0;
    await _service.exportToFile(_aircraftList, filePath);
    return 1;
  }

  Future<bool> updateAircraftByIdentifier(String? identifier) async {
    _pendingIdentifier = identifier;
    if (_isLoading || _aircraftList.isEmpty) return false;
    final selected = _resolveAircraftByIdentifier(identifier);
    if (selected == null) return false;
    if (_selectedAircraft?.id == selected.id) return true;
    _selectedAircraft = selected;
    _currentPhase = ChecklistPhase.coldAndDark;
    notifyListeners();
    return true;
  }

  AircraftChecklist? _resolveAircraftByIdentifier(String? identifier) {
    final normalized = (identifier ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return _findGenericChecklist() ?? _aircraftList.first;
    }
    for (final aircraft in _aircraftList) {
      final id = aircraft.id.toLowerCase();
      final name = aircraft.name.toLowerCase();
      if (normalized.contains(id) || normalized.contains(name)) {
        return aircraft;
      }
    }
    if (_looksLikeB737(normalized)) {
      return _findByFamily(AircraftFamily.b737) ??
          _findGenericChecklist() ??
          _aircraftList.first;
    }
    if (_looksLikeA320(normalized)) {
      return _findByFamily(AircraftFamily.a320) ??
          _findGenericChecklist() ??
          _aircraftList.first;
    }
    return _findGenericChecklist() ?? _aircraftList.first;
  }

  bool _looksLikeA320(String text) {
    return text.contains('a320') ||
        text.contains('a319') ||
        text.contains('a321') ||
        text.contains('a32n') ||
        text.contains('airbus a3');
  }

  bool _looksLikeB737(String text) {
    return text.contains('b737') ||
        text.contains('737') ||
        text.contains('b738') ||
        text.contains('zibo') ||
        text.contains('boeing 737');
  }

  AircraftChecklist? _findByFamily(AircraftFamily family) {
    for (final aircraft in _aircraftList) {
      if (aircraft.family == family) {
        return aircraft;
      }
    }
    return null;
  }

  AircraftChecklist? _findGenericChecklist() {
    for (final aircraft in _aircraftList) {
      if (aircraft.family == AircraftFamily.generic ||
          aircraft.id.toLowerCase() == 'generic') {
        return aircraft;
      }
    }
    return null;
  }

  void _applyAircraftList(List<AircraftChecklist> list) {
    _aircraftList = list;
    if (_aircraftList.isEmpty) {
      _selectedAircraft = null;
      return;
    }
    final selectedId = _selectedAircraft?.id;
    if (selectedId != null) {
      for (final aircraft in _aircraftList) {
        if (aircraft.id == selectedId) {
          _selectedAircraft = aircraft;
          _currentPhase = ChecklistPhase.coldAndDark;
          return;
        }
      }
    }
    _selectedAircraft = _aircraftList.first;
    _currentPhase = ChecklistPhase.coldAndDark;
  }
}
