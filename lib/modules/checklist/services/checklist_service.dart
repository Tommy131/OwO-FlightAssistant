import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/services/persistence_service.dart';
import '../data/a320_checklist.dart';
import '../data/b737_checklist.dart';
import '../data/generic_checklist.dart';
import '../models/flight_checklist.dart';

class ChecklistService {
  static final ChecklistService _instance = ChecklistService._internal();
  factory ChecklistService() => _instance;
  ChecklistService._internal();

  List<AircraftChecklist> getBuiltInChecklists() {
    return [
      GenericChecklist.create('通用机型'),
      A320Checklist.create('A320-200 / A321 / A319'),
      B737Checklist.create('B737-800 / Max'),
    ];
  }

  String? getChecklistDirectoryPath() {
    final rootPath = PersistenceService().rootPath;
    if (rootPath == null) return null;
    return p.join(rootPath, 'checklist');
  }

  Future<List<AircraftChecklist>> loadFromDirectory() async {
    final dirPath = getChecklistDirectoryPath();
    if (dirPath == null) return [];
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];
    final entries = await dir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.json')
        .toList();

    if (entries.isEmpty) return [];
    final List<AircraftChecklist> result = [];
    for (final file in entries) {
      final fileList = await loadFromFile(file);
      if (fileList.isNotEmpty) {
        result.addAll(fileList);
      }
    }
    return result;
  }

  Future<List<AircraftChecklist>> loadFromFile(File file) async {
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final dynamic jsonData = json.decode(content);
      return _parseChecklistPayload(jsonData);
    } catch (_) {
      return [];
    }
  }

  Future<void> exportToFile(
    List<AircraftChecklist> aircraft,
    String targetPath,
  ) async {
    final payload = _serializeChecklistPayload(aircraft);
    final file = File(targetPath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  List<AircraftChecklist> _parseChecklistPayload(dynamic jsonData) {
    if (jsonData is Map<String, dynamic>) {
      if (jsonData['aircraft'] is List) {
        return _parseAircraftList(jsonData['aircraft'] as List);
      }
      if (jsonData['sections'] is List) {
        final aircraft = _parseAircraft(jsonData);
        return aircraft == null ? [] : [aircraft];
      }
    }
    if (jsonData is List) {
      return _parseAircraftList(jsonData);
    }
    return [];
  }

  List<AircraftChecklist> _parseAircraftList(List<dynamic> list) {
    final List<AircraftChecklist> result = [];
    for (final entry in list) {
      if (entry is Map<String, dynamic>) {
        final aircraft = _parseAircraft(entry);
        if (aircraft != null) {
          result.add(aircraft);
        }
      }
    }
    return result;
  }

  AircraftChecklist? _parseAircraft(Map<String, dynamic> map) {
    final id = map['id']?.toString();
    final name = map['name']?.toString();
    final sectionsRaw = map['sections'];
    if (id == null || id.isEmpty || name == null || sectionsRaw is! List) {
      return null;
    }
    final familyValue = map['family']?.toString();
    final family = _parseFamily(familyValue);

    final List<ChecklistSection> sections = [];
    for (final sectionRaw in sectionsRaw) {
      if (sectionRaw is! Map<String, dynamic>) continue;
      final phaseValue = sectionRaw['phase']?.toString();
      final phase = _parsePhase(phaseValue);
      if (phase == null) continue;
      final itemsRaw = sectionRaw['items'];
      if (itemsRaw is! List) continue;
      final List<ChecklistItem> items = [];
      for (final itemRaw in itemsRaw) {
        if (itemRaw is! Map<String, dynamic>) continue;
        final itemId = itemRaw['id']?.toString();
        final task = itemRaw['task']?.toString();
        final response = itemRaw['response']?.toString();
        if (itemId == null || task == null || response == null) continue;
        items.add(
          ChecklistItem(
            id: itemId,
            task: task,
            response: response,
            detail: itemRaw['detail']?.toString(),
          ),
        );
      }
      sections.add(ChecklistSection(phase: phase, items: items));
    }

    if (sections.isEmpty) return null;
    return AircraftChecklist(
      id: id,
      name: name,
      family: family,
      sections: sections,
    );
  }

  AircraftFamily _parseFamily(String? value) {
    if (value == null) return AircraftFamily.generic;
    final normalized = value.toLowerCase();
    for (final family in AircraftFamily.values) {
      if (family.name.toLowerCase() == normalized) return family;
    }
    if (normalized.contains('737')) return AircraftFamily.b737;
    if (normalized.contains('320') || normalized.contains('321')) {
      return AircraftFamily.a320;
    }
    return AircraftFamily.generic;
  }

  ChecklistPhase? _parsePhase(String? value) {
    if (value == null) return null;
    for (final phase in ChecklistPhase.values) {
      if (phase.name == value || phase.labelKey == value) {
        return phase;
      }
    }
    return null;
  }

  Map<String, dynamic> _serializeChecklistPayload(
    List<AircraftChecklist> aircraft,
  ) {
    return {
      'version': 1,
      'aircraft': aircraft.map(_serializeAircraft).toList(),
    };
  }

  Map<String, dynamic> _serializeAircraft(AircraftChecklist aircraft) {
    return {
      'id': aircraft.id,
      'name': aircraft.name,
      'family': aircraft.family.name,
      'sections': aircraft.sections.map(_serializeSection).toList(),
    };
  }

  Map<String, dynamic> _serializeSection(ChecklistSection section) {
    return {
      'phase': section.phase.name,
      'items': section.items.map(_serializeItem).toList(),
    };
  }

  Map<String, dynamic> _serializeItem(ChecklistItem item) {
    return {
      'id': item.id,
      'task': item.task,
      'response': item.response,
      if (item.detail != null) 'detail': item.detail,
    };
  }
}
