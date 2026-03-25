import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/persistence_service.dart';
import '../../models/map_taxiway_node.dart';
import '../../models/map_taxiway_segment.dart';
import '../map_taxiway_models.dart';

// ─────────────────────────────────────────────────────────────────
// 滑行路线文件读写组件
//
// 职责（单一）：
//   1. 解析 / 构建 JSON 文件格式（版本兼容 v1/v2）
//   2. 负责文件目录管理（确保 taxiway/ 目录存在）
//   3. 提供文件选择（FilePicker） / 文件列表等平台 I/O 能力
//   4. 提供路径规范化、ICAO 提取等纯文本工具
//
// 不包含任何 UI 逻辑，不依赖 Flutter Widget 层。
// ─────────────────────────────────────────────────────────────────
class MapTaxiwayFileComponent {
  MapTaxiwayFileComponent._();

  // ── 公开接口 ──────────────────────────────────────────────────

  /// 将节点与线段数据序列化并写入文件，返回写入的节点数（失败返回负数）。
  ///
  /// - 若 [targetPath] 为 null，会弹出系统保存对话框让用户选择路径。
  /// - 最终路径遵循 `<ICAO>_taxiway_<name>.json` 命名规范。
  static Future<int> exportToFile({
    required List<MapTaxiwayNode> nodes,
    required List<MapTaxiwaySegment> segments,
    required String airportIcao,
    required DateTime? loadedCreatedAt,
    required String? loadedFilePath,
  }) async {
    if (nodes.isEmpty) return -1;

    final taxiwayDirectory = await _ensureTaxiwayDirectory();
    var targetPath = loadedFilePath;

    if (targetPath == null || targetPath.trim().isEmpty) {
      if (_isMobilePlatform()) {
        targetPath = p.join(
          taxiwayDirectory.path,
          _buildTaxiwayFileName(airportIcao),
        );
      } else {
        final picked = await _saveTaxiwayFilePath(
          initialDirectory: taxiwayDirectory.path,
          fileName: _buildTaxiwayFileName(airportIcao),
        );
        if (picked == null || picked.trim().isEmpty) return 0;
        targetPath = _normalizeTaxiwaySavePath(
          filePath: picked,
          airportIcao: airportIcao,
        );
      }
    }

    final file = File(_normalizeJsonFilePath(targetPath));
    final now = DateTime.now();
    final createdAt = loadedCreatedAt ?? now;

    final payload = _buildPayload(
      nodes: nodes,
      segments: segments,
      airportIcao: airportIcao,
      createdAt: createdAt,
      lastSavedAt: now,
    );
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return nodes.length;
  }

  /// 弹出文件选择对话框，从用户选中的 JSON 文件中读取滑行路线数据。
  static Future<MapTaxiwayFileData?> importFromFilePicker() async {
    final taxiwayDirectory = await _ensureTaxiwayDirectory();
    final result = await _pickTaxiwayFile(
      initialDirectory: taxiwayDirectory.path,
    );
    final filePath = result?.files.single.path;
    if (filePath == null || filePath.trim().isEmpty) return null;
    return loadFromPath(filePath);
  }

  /// 从已知路径加载滑行路线文件并解析。
  static Future<MapTaxiwayFileData?> loadFromPath(String filePath) async {
    return _loadTaxiwayFileDataFromPath(filePath);
  }

  /// 列出指定机场的所有滑行路线文件摘要，按最後修改时间降序排列。
  static Future<List<MapTaxiwayFileSummary>> listFilesForAirport(
    String icao,
  ) async {
    final resolvedIcao = icao.trim().toUpperCase();
    if (resolvedIcao.isEmpty || resolvedIcao == 'UNKNOWN') return const [];

    final taxiwayDirectory = await _ensureTaxiwayDirectory();
    if (!await taxiwayDirectory.exists()) return const [];

    final summaries = <MapTaxiwayFileSummary>[];
    await for (final entity in taxiwayDirectory.list()) {
      if (entity is! File) continue;
      final fileName = p.basename(entity.path);
      if (!_isTaxiwayFileForAirport(fileName, resolvedIcao)) continue;

      final stat = await entity.stat();
      final data = await _loadTaxiwayFileDataFromPath(entity.path);
      if (data == null || data.nodes.isEmpty) continue;

      summaries.add(MapTaxiwayFileSummary(
        filePath: entity.path,
        fileName: fileName,
        lastModified: stat.modified,
        nodeCount: data.nodes.length,
      ));
    }
    summaries.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return summaries;
  }

  /// 从文件路径中提取 ICAO 代码（例如 `ZGSZ_taxiway_custom.json` → `ZGSZ`）。
  static String? extractIcaoFromPath(String filePath) {
    final fileName = p.basename(filePath).trim();
    if (fileName.isEmpty) return null;
    final normalized = fileName.toUpperCase();
    final markerIndex = normalized.indexOf('_TAXIWAY_');
    if (markerIndex <= 0) return null;
    final icao = normalized.substring(0, markerIndex).trim();
    return (icao.isEmpty || icao == 'UNKNOWN') ? null : icao;
  }

  /// 规范化 JSON 文件路径（确保以 `.json` 结尾）。
  static String normalizeJsonFilePath(String filePath) =>
      _normalizeJsonFilePath(filePath);

  /// 规范化保存路径（确保命名符合 `<ICAO>_taxiway_<name>.json` 规范）。
  static String normalizeSavePath({
    required String filePath,
    required String airportIcao,
  }) => _normalizeTaxiwaySavePath(filePath: filePath, airportIcao: airportIcao);

  // ── 私有方法 ──────────────────────────────────────────────────

  /// 构建 JSON 序列化 payload。
  static Map<String, dynamic> _buildPayload({
    required List<MapTaxiwayNode> nodes,
    required List<MapTaxiwaySegment> segments,
    required String airportIcao,
    required DateTime createdAt,
    required DateTime lastSavedAt,
  }) {
    return {
      'version': 2,
      'type': 'custom_taxiway_route',
      'header': {
        'airport_icao': airportIcao,
        'created_at': createdAt.toIso8601String(),
        'last_saved_at': lastSavedAt.toIso8601String(),
      },
      'payload': {
        'nodes': nodes.map((node) => {
          'lat': node.latitude,
          'lon': node.longitude,
          if (node.name != null) 'name': node.name,
          if (node.colorHex != null) 'color': node.colorHex,
          if (node.note != null) 'note': node.note,
        }).toList(),
        'segments': segments.map((segment) => {
          if (segment.name != null) 'name': segment.name,
          if (segment.colorHex != null) 'color': segment.colorHex,
          if (segment.note != null) 'note': segment.note,
          'line_type': segment.lineType.value,
          'curvature': segment.curvature,
          'curve_direction': segment.curveDirection.value,
        }).toList(),
      },
    };
  }

  /// 从 JSON 文件路径中解析出完整的滑行路线数据。
  ///
  /// 支持多种旧版格式（v1 直接 nodes/points 字段）。
  static Future<MapTaxiwayFileData?> _loadTaxiwayFileDataFromPath(
    String filePath,
  ) async {
    try {
      final raw = json.decode(await File(filePath).readAsString());
      final root = _asMap(raw);
      if (root == null) return null;

      final header = _asMap(root['header']);
      final payloadMap = _asMap(root['payload']);

      final importedNodes = <MapTaxiwayNode>[];
      final importedSegments = <MapTaxiwaySegment>[];

      // 优先读取 v2 payload.nodes
      final payloadNodesValue = payloadMap?['nodes'];
      if (payloadNodesValue is List) {
        for (final item in payloadNodesValue) {
          final node = _toNode(item);
          if (node != null) importedNodes.add(node);
        }
      }

      // 读取 v2 payload.segments
      final payloadSegmentsValue = payloadMap?['segments'];
      if (payloadSegmentsValue is List) {
        for (final item in payloadSegmentsValue) {
          final segment = _toSegment(item);
          if (segment != null) importedSegments.add(segment);
        }
      }

      // 兼容 v1 顶层 nodes 字段
      if (importedNodes.isEmpty) {
        final nodesValue = root['nodes'];
        if (nodesValue is List) {
          for (final item in nodesValue) {
            final node = _toNode(item);
            if (node != null) importedNodes.add(node);
          }
        }
      }

      // 兼容更早期的 points 字段
      if (importedNodes.isEmpty) {
        final pointsValue = root['points'];
        if (pointsValue is! List) return null;
        for (final item in pointsValue) {
          final node = _toNode(item);
          if (node != null) importedNodes.add(node);
        }
      }

      if (importedNodes.isEmpty) return null;

      // 提取元数据
      final icaoFromHeader = header?['airport_icao']?.toString();
      final normalizedIcao = icaoFromHeader?.trim().toUpperCase();
      final createdAt = DateTime.tryParse(
        header?['created_at']?.toString() ?? '',
      );

      return MapTaxiwayFileData(
        nodes: importedNodes,
        segments: importedSegments,
        airportIcao:
            normalizedIcao?.isEmpty ?? true ? null : normalizedIcao,
        createdAt: createdAt,
      );
    } catch (_) {
      return null;
    }
  }

  /// 确保 taxiway 目录存在，不存在则递归创建。
  static Future<Directory> _ensureTaxiwayDirectory() async {
    final persistence = PersistenceService();
    await persistence.ensureReady();
    final rootPath = persistence.rootPath?.trim();
    final fallbackPath = PersistenceService.getProcessedRootPath(
      PersistenceService.getAppCacheRootPath(),
    );
    final storageRootPath =
        (rootPath == null || rootPath.isEmpty) ? fallbackPath : rootPath;
    final directory = Directory(p.join(storageRootPath, 'taxiway'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// 弹出系统文件保存对话框并返回用户选择的路径。
  static Future<String?> _saveTaxiwayFilePath({
    required String initialDirectory,
    required String fileName,
  }) async {
    try {
      return await FilePicker.platform.saveFile(
        initialDirectory: initialDirectory,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } catch (_) {
      try {
        return await FilePicker.platform.saveFile(
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
      } catch (_) {
        return null;
      }
    }
  }

  static bool _isMobilePlatform() =>
      Platform.isAndroid || Platform.isIOS;

  /// 弹出系统文件选择对话框并返回用户选择的结果。
  static Future<FilePickerResult?> _pickTaxiwayFile({
    required String initialDirectory,
  }) async {
    try {
      return await FilePicker.platform.pickFiles(
        initialDirectory: initialDirectory,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } catch (_) {
      return FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    }
  }

  /// 判断文件名是否属于指定机场的滑行路线文件。
  static bool _isTaxiwayFileForAirport(String fileName, String icao) {
    final normalized = fileName.trim().toUpperCase();
    return normalized.startsWith('${icao}_TAXIWAY_') &&
        normalized.endsWith('.JSON');
  }

  /// 根据 ICAO 和当前时间生成默认文件名。
  static String _buildTaxiwayFileName(String icao) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return '${icao}_taxiway_$timestamp.json';
  }

  /// 规范化保存路径以符合命名规范。
  static String _normalizeTaxiwaySavePath({
    required String filePath,
    required String airportIcao,
  }) {
    final normalizedPath = _normalizeJsonFilePath(filePath);
    final directory = p.dirname(normalizedPath);
    final baseName =
        p.basenameWithoutExtension(normalizedPath).trim();
    final normalizedIcao = airportIcao.trim().toUpperCase();
    final prefix = '${normalizedIcao}_taxiway_';
    final lowerBaseName = baseName.toLowerCase();
    final customName = lowerBaseName.startsWith(prefix)
        ? baseName.substring(prefix.length)
        : baseName;
    final safeCustomName =
        customName.trim().isEmpty ? 'custom' : customName;
    return p.join(directory, '$prefix$safeCustomName.json');
  }

  /// 确保路径以 `.json` 结尾。
  static String _normalizeJsonFilePath(String filePath) {
    final trimmed = filePath.trim();
    if (trimmed.isEmpty) return trimmed;
    if (p.extension(trimmed).toLowerCase() == '.json') return trimmed;
    return '$trimmed.json';
  }

  // ── JSON 解析工具 ──────────────────────────────────────────────

  /// 将动态值转成 `Map<String, dynamic>`，失败返回 null。
  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry('$k', val));
    return null;
  }

  /// 将动态值转成 `double`，失败返回 null。
  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return double.tryParse(text);
  }

  /// 规范化字符串：去首尾空白，若为空则返回 null。
  static String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    return (normalized == null || normalized.isEmpty) ? null : normalized;
  }

  /// 规范化颜色十六进制字符串（如 `#FF0000`），格式不合法则返回 null。
  static String? _normalizeTaxiwayColorHex(String? value) {
    final normalized = _normalizeOptionalText(value);
    if (normalized == null) return null;
    var compact = normalized.toUpperCase();
    if (compact.startsWith('#')) compact = compact.substring(1);
    if (RegExp(r'^[0-9A-F]{6}$').hasMatch(compact)) return '#$compact';
    if (RegExp(r'^[0-9A-F]{8}$').hasMatch(compact)) return '#$compact';
    return null;
  }

  /// 将原始 Map 数据解析为 [MapTaxiwayNode]。
  static MapTaxiwayNode? _toNode(dynamic item) {
    final map = _asMap(item);
    if (map == null) return null;
    final lat = _toDouble(map['lat'] ?? map['latitude']);
    final lon = _toDouble(map['lon'] ?? map['lng'] ?? map['longitude']);
    if (lat == null || lon == null) return null;
    if (!_isValidCoordinate(lat, lon)) return null;
    return MapTaxiwayNode(
      latitude: lat,
      longitude: lon,
      name: _normalizeOptionalText(map['name']?.toString()),
      colorHex: _normalizeTaxiwayColorHex(
        map['color']?.toString() ?? map['colorHex']?.toString(),
      ),
      note: _normalizeOptionalText(map['note']?.toString()),
    );
  }

  /// 将原始 Map 数据解析为 [MapTaxiwaySegment]。
  static MapTaxiwaySegment? _toSegment(dynamic item) {
    final map = _asMap(item);
    if (map == null) return null;
    final curvatureRaw = _toDouble(map['curvature']);
    final curvature = (curvatureRaw != null &&
            !curvatureRaw.isNaN &&
            !curvatureRaw.isInfinite)
        ? curvatureRaw.clamp(0.0, 1.0).toDouble()
        : const MapTaxiwaySegment().curvature;
    return MapTaxiwaySegment(
      name: _normalizeOptionalText(map['name']?.toString()),
      colorHex: _normalizeTaxiwayColorHex(
        map['color']?.toString() ?? map['colorHex']?.toString(),
      ),
      note: _normalizeOptionalText(map['note']?.toString()),
      lineType: MapTaxiwaySegmentLineTypeX.fromValue(
        map['line_type']?.toString() ?? map['lineType']?.toString(),
      ),
      curveDirection: MapTaxiwaySegmentCurveDirectionX.fromValue(
        map['curve_direction']?.toString() ??
            map['curveDirection']?.toString(),
      ),
      curvature: curvature,
    );
  }

  /// 简单的经纬度有效性校验。
  static bool _isValidCoordinate(double lat, double lon) {
    return lat.isFinite &&
        lon.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lon >= -180 &&
        lon <= 180;
  }
}
