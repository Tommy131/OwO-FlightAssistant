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
      final ext = p.extension(file.path).toLowerCase();
      if (ext == '.json') {
        final dynamic jsonData = json.decode(content);
        return _normalizeImportedChecklist(
          _parseChecklistPayload(jsonData),
          sourceHint: p.basenameWithoutExtension(file.path),
        );
      }
      final parsed = _parseTextChecklistPayload(content);
      return _normalizeImportedChecklist(
        parsed,
        sourceHint: p.basenameWithoutExtension(file.path),
      );
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

  List<AircraftChecklist> _parseTextChecklistPayload(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
    if (lines.isEmpty) {
      return [];
    }
    if (lines.any((line) => line.contains('|'))) {
      return _parsePipeChecklist(lines);
    }
    return _parsePlainChecklist(lines);
  }

  List<AircraftChecklist> _parsePipeChecklist(List<String> lines) {
    final sections = <ChecklistPhase, List<ChecklistItem>>{};
    String name = 'Imported Checklist';
    String id = 'imported_checklist';
    AircraftFamily family = AircraftFamily.generic;
    var index = 0;
    for (final line in lines) {
      final parts = line.split('|').map((part) => part.trim()).toList();
      if (parts.isEmpty) {
        continue;
      }
      final key = parts.first.toLowerCase();
      if (key == 'name' && parts.length >= 2) {
        name = parts[1];
        continue;
      }
      if (key == 'id' && parts.length >= 2) {
        id = _normalizeId(parts[1]);
        continue;
      }
      if (key == 'family' && parts.length >= 2) {
        family = _parseFamily(parts[1]);
        continue;
      }
      final phase = _parsePhase(parts[0]) ?? _parsePhaseByLabel(parts[0]);
      if (phase == null || parts.length < 3) {
        continue;
      }
      final item = ChecklistItem(
        id: '$id-${phase.name}-${index++}',
        task: parts[1],
        response: parts[2],
        detail: parts.length >= 4 ? parts[3] : null,
      );
      sections.putIfAbsent(phase, () => <ChecklistItem>[]).add(item);
    }
    return _buildTextChecklist(
      id: id,
      name: name,
      family: family,
      sections: sections,
    );
  }

  List<AircraftChecklist> _parsePlainChecklist(List<String> lines) {
    final sections = <ChecklistPhase, List<ChecklistItem>>{};
    String id = 'imported_checklist';
    String name = 'Imported Checklist';
    AircraftFamily family = AircraftFamily.generic;
    ChecklistPhase? currentPhase;
    var index = 0;
    for (final line in lines) {
      final normalizedLine = line.trim();
      if (normalizedLine.startsWith('name:')) {
        name = normalizedLine.substring(5).trim();
        continue;
      }
      if (normalizedLine.startsWith('id:')) {
        id = _normalizeId(normalizedLine.substring(3).trim());
        continue;
      }
      if (normalizedLine.startsWith('family:')) {
        family = _parseFamily(normalizedLine.substring(7).trim());
        continue;
      }
      if (normalizedLine.startsWith('[') && normalizedLine.endsWith(']')) {
        final phaseRaw = normalizedLine.substring(1, normalizedLine.length - 1);
        currentPhase = _parsePhase(phaseRaw) ?? _parsePhaseByLabel(phaseRaw);
        continue;
      }
      final separator = normalizedLine.contains('=>') ? '=>' : ':';
      if (currentPhase == null || !normalizedLine.contains(separator)) {
        continue;
      }
      final splitIndex = normalizedLine.indexOf(separator);
      final task = normalizedLine.substring(0, splitIndex).trim();
      final response = normalizedLine.substring(splitIndex + separator.length).trim();
      if (task.isEmpty || response.isEmpty) {
        continue;
      }
      final item = ChecklistItem(
        id: '$id-${currentPhase.name}-${index++}',
        task: task,
        response: response,
      );
      sections.putIfAbsent(currentPhase, () => <ChecklistItem>[]).add(item);
    }
    return _buildTextChecklist(
      id: id,
      name: name,
      family: family,
      sections: sections,
    );
  }

  List<AircraftChecklist> _buildTextChecklist({
    required String id,
    required String name,
    required AircraftFamily family,
    required Map<ChecklistPhase, List<ChecklistItem>> sections,
  }) {
    if (sections.isEmpty) {
      return [];
    }
    final list = sections.entries
        .map((entry) => ChecklistSection(phase: entry.key, items: entry.value))
        .toList()
      ..sort(
        (a, b) => ChecklistPhase.values
            .indexOf(a.phase)
            .compareTo(ChecklistPhase.values.indexOf(b.phase)),
      );
    return [
      AircraftChecklist(
        id: _normalizeId(id),
        name: name.trim().isEmpty ? 'Imported Checklist' : name.trim(),
        family: family,
        sections: list,
      ),
    ];
  }

  ChecklistPhase? _parsePhaseByLabel(String value) {
    final normalized = value.trim().toLowerCase();
    final aliases = <ChecklistPhase, List<String>>{
      ChecklistPhase.coldAndDark: ['cold', 'dark', 'cold and dark', '关车', '冷舱'],
      ChecklistPhase.beforePushback: ['pushback', '推出前'],
      ChecklistPhase.beforeTaxi: ['taxi', '滑行前'],
      ChecklistPhase.beforeTakeoff: ['takeoff', '起飞前'],
      ChecklistPhase.cruise: ['cruise', '巡航'],
      ChecklistPhase.beforeDescent: ['descent', '下降前'],
      ChecklistPhase.beforeApproach: ['approach', '进近前'],
      ChecklistPhase.afterLanding: ['after landing', 'landing', '落地后'],
      ChecklistPhase.parking: ['parking', '停机'],
    };
    for (final entry in aliases.entries) {
      if (entry.value.any((alias) => normalized.contains(alias))) {
        return entry.key;
      }
    }
    return null;
  }

  List<AircraftChecklist> _normalizeImportedChecklist(
    List<AircraftChecklist> source, {
    required String sourceHint,
  }) {
    if (source.isEmpty) {
      return source;
    }
    final normalizedHint = sourceHint.trim();
    return source.map((aircraft) {
      final inferredFamily = _inferFamily(
        seed: '${aircraft.id} ${aircraft.name} $normalizedHint',
      );
      final family = aircraft.family == AircraftFamily.generic
          ? inferredFamily
          : aircraft.family;
      final idSeed = aircraft.id.trim().isEmpty
          ? _normalizeId('$normalizedHint checklist')
          : aircraft.id;
      return AircraftChecklist(
        id: _normalizeId(idSeed),
        name: aircraft.name,
        family: family,
        sections: aircraft.sections,
      );
    }).toList();
  }

  AircraftFamily _inferFamily({required String seed}) {
    final normalized = seed.toLowerCase();
    if (normalized.contains('737') || normalized.contains('b738')) {
      return AircraftFamily.b737;
    }
    if (normalized.contains('320') ||
        normalized.contains('321') ||
        normalized.contains('319') ||
        normalized.contains('a32')) {
      return AircraftFamily.a320;
    }
    return AircraftFamily.generic;
  }

  String _normalizeId(String raw) {
    final cleaned = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (cleaned.isEmpty) {
      return 'imported_checklist';
    }
    return cleaned;
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
