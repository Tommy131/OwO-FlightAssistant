import '../models/flight_checklist.dart';

/// 检查单文件解析器
/// 负责将 JSON 或纯文本格式的检查单数据解析为 [AircraftChecklist] 对象列表
class ChecklistParser {
  /// 将 JSON 数据解析为 [AircraftChecklist] 列表
  /// 支持以下三种 JSON 格式：
  ///   1. `{ "aircraft": [...] }` — 多机型列表
  ///   2. `{ "sections": [...] }` — 单机型（直接节段形式）
  ///   3. `[...]` — 顶层数组形式
  List<AircraftChecklist> parseJson(dynamic jsonData) {
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

  /// 将纯文本内容解析为 [AircraftChecklist] 列表
  /// 支持管道符分隔（Pipe）和冒号/箭头分隔（Plain）两种格式
  List<AircraftChecklist> parseText(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
    if (lines.isEmpty) return [];
    // 含管道符则以管道格式解析，否则用纯文本格式
    if (lines.any((line) => line.contains('|'))) {
      return _parsePipeFormat(lines);
    }
    return _parsePlainFormat(lines);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 管道符格式解析
  // ──────────────────────────────────────────────────────────────────────────

  /// 解析 `phase|task|response[|detail]` 形式的管道符格式
  List<AircraftChecklist> _parsePipeFormat(List<String> lines) {
    final sections = <ChecklistPhase, List<ChecklistItem>>{};
    String name = 'Imported Checklist';
    String id = 'imported_checklist';
    AircraftFamily family = AircraftFamily.generic;
    var index = 0;

    for (final line in lines) {
      final parts = line.split('|').map((p) => p.trim()).toList();
      if (parts.isEmpty) continue;

      final key = parts.first.toLowerCase();
      // 元信息头部行处理
      if (key == 'name' && parts.length >= 2) {
        name = parts[1];
        continue;
      }
      if (key == 'id' && parts.length >= 2) {
        id = normalizeId(parts[1]);
        continue;
      }
      if (key == 'family' && parts.length >= 2) {
        family = parseFamily(parts[1]);
        continue;
      }

      // 检查单条目行
      final phase = parsePhase(parts[0]) ?? parsePhaseByLabel(parts[0]);
      if (phase == null || parts.length < 3) continue;

      final item = ChecklistItem(
        id: '$id-${phase.name}-${index++}',
        task: parts[1],
        response: parts[2],
        detail: parts.length >= 4 ? parts[3] : null,
      );
      sections.putIfAbsent(phase, () => <ChecklistItem>[]).add(item);
    }
    return _buildFromSections(
      id: id,
      name: name,
      family: family,
      sections: sections,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 纯文本格式解析
  // ──────────────────────────────────────────────────────────────────────────

  /// 解析 `[phase]\ntask: response` 或 `task => response` 形式的纯文本格式
  List<AircraftChecklist> _parsePlainFormat(List<String> lines) {
    final sections = <ChecklistPhase, List<ChecklistItem>>{};
    String id = 'imported_checklist';
    String name = 'Imported Checklist';
    AircraftFamily family = AircraftFamily.generic;
    ChecklistPhase? currentPhase;
    var index = 0;

    for (final line in lines) {
      // 元信息行
      if (line.startsWith('name:')) {
        name = line.substring(5).trim();
        continue;
      }
      if (line.startsWith('id:')) {
        id = normalizeId(line.substring(3).trim());
        continue;
      }
      if (line.startsWith('family:')) {
        family = parseFamily(line.substring(7).trim());
        continue;
      }
      // 阶段段落标题 `[phase]`
      if (line.startsWith('[') && line.endsWith(']')) {
        final phaseRaw = line.substring(1, line.length - 1);
        currentPhase = parsePhase(phaseRaw) ?? parsePhaseByLabel(phaseRaw);
        continue;
      }
      // 条目行
      final separator = line.contains('=>') ? '=>' : ':';
      if (currentPhase == null || !line.contains(separator)) continue;
      final splitIndex = line.indexOf(separator);
      final task = line.substring(0, splitIndex).trim();
      final response = line.substring(splitIndex + separator.length).trim();
      if (task.isEmpty || response.isEmpty) continue;

      final item = ChecklistItem(
        id: '$id-${currentPhase.name}-${index++}',
        task: task,
        response: response,
      );
      sections.putIfAbsent(currentPhase, () => <ChecklistItem>[]).add(item);
    }
    return _buildFromSections(
      id: id,
      name: name,
      family: family,
      sections: sections,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // JSON 对象级解析
  // ──────────────────────────────────────────────────────────────────────────

  List<AircraftChecklist> _parseAircraftList(List<dynamic> list) {
    final result = <AircraftChecklist>[];
    for (final entry in list) {
      if (entry is Map<String, dynamic>) {
        final aircraft = _parseAircraft(entry);
        if (aircraft != null) result.add(aircraft);
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

    final family = parseFamily(map['family']?.toString());
    final sections = <ChecklistSection>[];

    for (final sectionRaw in sectionsRaw) {
      if (sectionRaw is! Map<String, dynamic>) continue;
      final phase = parsePhase(sectionRaw['phase']?.toString());
      if (phase == null) continue;
      final itemsRaw = sectionRaw['items'];
      if (itemsRaw is! List) continue;

      final items = <ChecklistItem>[];
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

  // ──────────────────────────────────────────────────────────────────────────
  // 辅助工具
  // ──────────────────────────────────────────────────────────────────────────

  /// 从 sections Map 构建单条 [AircraftChecklist]
  List<AircraftChecklist> _buildFromSections({
    required String id,
    required String name,
    required AircraftFamily family,
    required Map<ChecklistPhase, List<ChecklistItem>> sections,
  }) {
    if (sections.isEmpty) return [];
    final list =
        sections.entries
            .map((e) => ChecklistSection(phase: e.key, items: e.value))
            .toList()
          ..sort(
            (a, b) => ChecklistPhase.values
                .indexOf(a.phase)
                .compareTo(ChecklistPhase.values.indexOf(b.phase)),
          );
    return [
      AircraftChecklist(
        id: normalizeId(id),
        name: name.trim().isEmpty ? 'Imported Checklist' : name.trim(),
        family: family,
        sections: list,
      ),
    ];
  }

  /// 将原始字符串规范化为合法 ID（小写、下划线连接）
  String normalizeId(String raw) {
    final cleaned = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'imported_checklist' : cleaned;
  }

  /// 根据名称字符串解析 [AircraftFamily]，支持模糊匹配
  AircraftFamily parseFamily(String? value) {
    if (value == null) return AircraftFamily.generic;
    final n = value.toLowerCase();
    for (final f in AircraftFamily.values) {
      if (f.name.toLowerCase() == n) return f;
    }
    if (n.contains('737')) return AircraftFamily.b737;
    if (n.contains('320') || n.contains('321')) return AircraftFamily.a320;
    return AircraftFamily.generic;
  }

  /// 根据枚举名称或 labelKey 精确匹配 [ChecklistPhase]
  ChecklistPhase? parsePhase(String? value) {
    if (value == null) return null;
    for (final phase in ChecklistPhase.values) {
      if (phase.name == value || phase.labelKey == value) return phase;
    }
    return null;
  }

  /// 根据自然语言标签模糊匹配 [ChecklistPhase]，支持中英文别名
  ChecklistPhase? parsePhaseByLabel(String value) {
    final n = value.trim().toLowerCase();
    const aliases = <ChecklistPhase, List<String>>{
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
      if (entry.value.any((alias) => n.contains(alias))) return entry.key;
    }
    return null;
  }
}
