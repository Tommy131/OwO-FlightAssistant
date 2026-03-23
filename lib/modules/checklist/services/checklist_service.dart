import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/services/persistence_service.dart';
import '../models/flight_checklist.dart';
import 'aircraft_resolver.dart';
import 'checklist_parser.dart';
import 'checklist_serializer.dart';

/// 检查单服务（协调层）
/// 统一对外提供检查单的加载、导出及内建数据访问能力
/// 具体的解析、序列化、机型推断职责已分别委托给对应的子层：
///   - [ChecklistParser]      — JSON / 文本解析
///   - [ChecklistSerializer]  — JSON 序列化
///   - [AircraftResolver]     — 机型匹配与内建清单
class ChecklistService {
  static final ChecklistService _instance = ChecklistService._internal();
  factory ChecklistService() => _instance;
  ChecklistService._internal();

  final _parser = ChecklistParser();
  final _serializer = ChecklistSerializer();
  final _resolver = AircraftResolver();

  // ──────────────────────────────────────────────────────────────────────────
  // 内建数据
  // ──────────────────────────────────────────────────────────────────────────

  /// 返回内建预置检查单列表（通用 / A320 / B737）
  List<AircraftChecklist> getBuiltInChecklists() =>
      _resolver.getBuiltInChecklists();

  // ──────────────────────────────────────────────────────────────────────────
  // 文件系统操作
  // ──────────────────────────────────────────────────────────────────────────

  /// 获取检查单目录路径（基于用户配置的根目录）
  String? getChecklistDirectoryPath() {
    final rootPath = PersistenceService().rootPath;
    if (rootPath == null) return null;
    return p.join(rootPath, 'checklist');
  }

  /// 从检查单目录扫描并加载所有 .json 文件
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

    final result = <AircraftChecklist>[];
    for (final file in entries) {
      final fileList = await loadFromFile(file);
      if (fileList.isNotEmpty) result.addAll(fileList);
    }
    return result;
  }

  /// 从单个文件加载检查单
  /// 支持 .json（JSON 格式）及其他文本格式（管道符 / 纯文本）
  Future<List<AircraftChecklist>> loadFromFile(File file) async {
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final sourceHint = p.basenameWithoutExtension(file.path);
      final ext = p.extension(file.path).toLowerCase();

      List<AircraftChecklist> parsed;
      if (ext == '.json') {
        parsed = _parser.parseJson(json.decode(content));
      } else {
        parsed = _parser.parseText(content);
      }
      return _normalizeImported(parsed, sourceHint: sourceHint);
    } catch (_) {
      return [];
    }
  }

  /// 将 [aircraft] 列表导出为格式化的 JSON 文件
  Future<void> exportToFile(
    List<AircraftChecklist> aircraft,
    String targetPath,
  ) async {
    final payload = _serializer.serialize(aircraft);
    final file = File(targetPath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 内部规范化
  // ──────────────────────────────────────────────────────────────────────────

  /// 对导入的检查单进行后处理：推断机型家族、规范化 ID
  List<AircraftChecklist> _normalizeImported(
    List<AircraftChecklist> source, {
    required String sourceHint,
  }) {
    if (source.isEmpty) return source;
    final hint = sourceHint.trim();
    return source.map((aircraft) {
      // 仅当机型为 generic 时，才尝试从文件名推断家族
      final inferredFamily = _resolver.inferFamily(
        seed: '${aircraft.id} ${aircraft.name} $hint',
      );
      final family = aircraft.family == AircraftFamily.generic
          ? inferredFamily
          : aircraft.family;
      // ID 为空时以文件名兜底
      final idSeed = aircraft.id.trim().isEmpty
          ? _parser.normalizeId('$hint checklist')
          : aircraft.id;
      return AircraftChecklist(
        id: _parser.normalizeId(idSeed),
        name: aircraft.name,
        family: family,
        sections: aircraft.sections,
      );
    }).toList();
  }
}
