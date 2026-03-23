import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/services/persistence_service.dart';
import '../../http/http_module.dart';
import '../models/airport_search_models.dart';

/// 机场搜索模块的底层服务类
/// 封装了网络请求 API 调用、ICAO 代码校验规则以及收藏列表的磁盘 I/O 读写。
class AirportSearchService {
  /// 收藏列表在本地存储目录中的文件路径名
  static const String _favoritesFileName = 'airport_favorites.json';

  /// 标准 4 位 ICAO 模式匹配
  static final RegExp _icaoPattern = RegExp(r'^[A-Z0-9]{4}$');

  /// 模糊搜索时的 ICAO 子串模式匹配 (1-4位)
  static final RegExp _icaoPartialPattern = RegExp(r'^[A-Z0-9]{1,4}$');

  /// 引用统一的核心持久化存储服务
  final PersistenceService _persistence;

  /// 辅助追踪异步保存状态，防止文件读写冲突 (并发锁备用)
  Future<void>? _activeSave;

  AirportSearchService({PersistenceService? persistence})
    : _persistence = persistence ?? PersistenceService();

  /// 归一化输入: 剔除空白并强制转换为大写，确保代码内部一致性。
  String normalizeIcao(String input) => input.trim().toUpperCase();

  /// 验证是否为完整的格式化的 4 位 ICAO 代码。
  bool isValidIcao(String input) {
    return _icaoPattern.hasMatch(normalizeIcao(input));
  }

  /// 验证是否为合法的 ICAO 输入片段 (如 ZG, VHH)，用于联想搜索预览。
  bool isValidIcaoPartial(String input) {
    return _icaoPartialPattern.hasMatch(normalizeIcao(input));
  }

  /// 发起复合异步请求: 通过 ICAO 同时加载机场基础详情和动态 METAR 气象数据。
  Future<AirportQueryResult> queryAirportAndMetar(String icao) async {
    final normalized = normalizeIcao(icao);
    if (!isValidIcao(normalized)) {
      throw const FormatException('invalid_icao');
    }

    // 并发执行查询任务，提高页面响应加载时间
    final responses = await Future.wait([
      HttpModule.client.getAirportByIcao(normalized),
      HttpModule.client.getMetarByIcao(normalized),
    ]);

    // 解码并转换为对应的 Data Model 对象
    final airportData = _decodeBodyToMap(responses[0].body);
    final metarData = _decodeBodyToMap(responses[1].body);

    return AirportQueryResult(
      airport: AirportDetailData.fromApi(airportData),
      metar: MetarData.fromApi(metarData),
    );
  }

  /// 单独获取机场静态详情信息。
  Future<AirportDetailData> fetchAirport(String icao) async {
    final normalized = normalizeIcao(icao);
    if (!isValidIcao(normalized)) {
      throw const FormatException('invalid_icao');
    }

    final response = await HttpModule.client.getAirportByIcao(normalized);
    final airportData = _decodeBodyToMap(response.body);
    return AirportDetailData.fromApi(airportData);
  }

  /// 请求模糊搜索/建议建议列表，默认返回最匹配的前 8 条搜索建议。
  Future<List<AirportSuggestionData>> suggestAirports(
    String query, {
    int limit = 8,
  }) async {
    final normalized = normalizeIcao(query);
    if (!isValidIcaoPartial(normalized)) {
      return [];
    }

    final response = await HttpModule.client.getAirportSuggestions(
      normalized,
      limit: limit,
    );
    final root = _decodeBodyToMap(response.body);

    // 解析不同结果包装层的兼容逻辑 (处理 suggestions 或项列表字段)
    final result = _asMap(root['result']) ?? root;
    final list =
        _asList(result['suggestions']) ?? _asList(result['items']) ?? [];

    return list
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry('$k', v)))
        .map(AirportSuggestionData.fromApi)
        .where((item) => item.icao.isNotEmpty)
        .toList();
  }

  /// 从设备本地存储异步读取收藏夹文件，并将其反序列化为对象列表。
  Future<List<FavoriteAirportEntry>> loadFavorites() async {
    // 确保底层持久化根目录已就绪 (通常是 appData 或 documents 路径)
    await _persistence.ensureReady();
    final file = await _favoritesFile();
    if (!await file.exists()) {
      return [];
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];

    final decoded = json.decode(content);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry('$k', v)))
        .map(FavoriteAirportEntry.fromJson)
        .where((item) => item.icao.isNotEmpty && isValidIcao(item.icao))
        .toList();
  }

  /// 将当前内存中的收藏记录持久化异步保存到磁盘 JSON 文件中。
  /// 内置顺序锁逻辑，防止多次几乎同时执行 save 操作引起文件被系统占用的奔溃。
  Future<void> saveFavorites(List<FavoriteAirportEntry> favorites) async {
    await _persistence.ensureReady();
    final payload = favorites.map((item) => item.toJson()).toList();
    final file = await _favoritesFile();
    final parent = file.parent;

    // 自动补齐目录深度
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    // 协作并发控制 (保证 IO 顺序)
    final currentSave = _activeSave;
    final completer = Completer<void>();
    _activeSave = completer.future;

    if (currentSave != null) {
      try {
        await currentSave;
      } catch (_) {
        /* 忽略前序失败详情，确保本次继续 */
      }
    }

    try {
      // 写入经过美化缩进的 JSON，方便开发者调试或手动修正本地数据
      final content = const JsonEncoder.withIndent('  ').convert(payload);
      await file.writeAsString(content, flush: true);
    } finally {
      completer.complete();
      if (_activeSave == completer.future) {
        _activeSave = null;
      }
    }
  }

  /// 计算收藏夹存放的完整路径逻辑 (依赖根存储路径)。
  Future<File> _favoritesFile() async {
    final rootPath = _persistence.rootPath;
    if (rootPath == null || rootPath.isEmpty) {
      throw StateError('persistence_path_not_ready');
    }
    return File(p.join(rootPath, _favoritesFileName));
  }

  /// 工具方法：解码 HTTP Body 负载并将 JSON 转换为 Map 格式。
  Map<String, dynamic> _decodeBodyToMap(String body) {
    final decoded = json.decode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
    throw const FormatException('invalid_response');
  }

  /// 辅助：空安全转换为 Map
  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry('$key', val));
    }
    return null;
  }

  /// 辅助：空安全转换为 List
  List<dynamic>? _asList(dynamic value) {
    if (value is List<dynamic>) return value;
    if (value is List) {
      return value.cast<dynamic>();
    }
    return null;
  }
}
