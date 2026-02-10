import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../core/utils/logger.dart';
import '../models/airport_detail_data.dart';
import '../data/xplane_apt_dat_parser.dart';
import '../data/lnm_database_parser.dart';
import '../data/airports_database.dart';
import 'weather_service.dart';

/// 数据源类型
enum AirportDataSource {
  aviationApi, // 免费API (airportdb.io)
  xplaneData, // X-Plane导航数据
  lnmData, // Little Navmap数据库
}

enum AirportCacheScope { persistent, temporary }

extension AirportDataSourceExtension on AirportDataSource {
  String get displayName {
    switch (this) {
      case AirportDataSource.aviationApi:
        return '在线API (airportdb.io)';
      case AirportDataSource.xplaneData:
        return 'X-Plane 导航数据';
      case AirportDataSource.lnmData:
        return 'Little Navmap 数据库';
    }
  }

  String get shortName {
    switch (this) {
      case AirportDataSource.aviationApi:
        return '在线 API';
      case AirportDataSource.xplaneData:
        return 'X-Plane';
      case AirportDataSource.lnmData:
        return 'Little Navmap';
    }
  }

  AirportDataSourceType get dataSourceType {
    switch (this) {
      case AirportDataSource.aviationApi:
        return AirportDataSourceType.aviationApi;
      case AirportDataSource.xplaneData:
        return AirportDataSourceType.xplaneData;
      case AirportDataSource.lnmData:
        return AirportDataSourceType.lnmData;
    }
  }
}

/// 机场详细信息服务
/// 支持多种数据源：免费API、X-Plane、Little Navmap
class AirportDetailService {
  static const String _onlineCachePrefix = 'airport_online_';
  static const String _localCachePrefix = 'airport_local_';
  static const String _dataSourceKey = 'airport_data_source';
  static const String _xplanePathKey = 'xplane_nav_data_path';
  static const String _lnmPathKey = 'lnm_nav_data_path';
  static const String _airportDbTokenKey = 'airportdb_token';
  static const String _tokenThresholdKey = 'token_consumption_threshold';
  static const String _tokenCountKey = 'token_consumption_count';

  // Aviation API (免费，无需API key)
  static const String _aviationApiBase = 'https://airportdb.io/api/v1/airport';
  static const int _temporaryCacheLimit = 200;

  final Map<String, AirportDetailData> _temporaryCache = {};

  /// 检查特定数据源是否可用（已配置）
  Future<bool> isDataSourceAvailable(AirportDataSource source) async {
    final prefs = await SharedPreferences.getInstance();
    switch (source) {
      case AirportDataSource.aviationApi:
        final token = prefs.getString(_airportDbTokenKey);
        if (token == null || token.isEmpty) return false;
        final threshold = prefs.getInt(_tokenThresholdKey) ?? 5000;
        final count = prefs.getInt(_tokenCountKey) ?? 0;
        return count < threshold;
      case AirportDataSource.xplaneData:
        final path = prefs.getString(_xplanePathKey);
        if (path == null || path.isEmpty) return false;
        return await File(path).exists();
      case AirportDataSource.lnmData:
        final path = prefs.getString(_lnmPathKey);
        if (path == null || path.isEmpty) return false;
        return await File(path).exists();
    }
  }

  /// 获取所有可用的数据源
  Future<List<AirportDataSource>> getAvailableDataSources() async {
    final available = <AirportDataSource>[];
    for (final source in AirportDataSource.values) {
      final isAvailable = await isDataSourceAvailable(source);
      if (isAvailable) {
        available.add(source);
      }
    }
    return available;
  }

  /// 获取当前数据源设置
  Future<AirportDataSource> getDataSource() async {
    final prefs = await SharedPreferences.getInstance();
    final sourceStr = prefs.getString(_dataSourceKey);
    AirportDataSource source = AirportDataSource.aviationApi;
    if (sourceStr != null) {
      source = AirportDataSource.values.firstWhere(
        (s) => s.name == sourceStr,
        orElse: () => AirportDataSource.aviationApi,
      );
    }
    final isAvailable = await isDataSourceAvailable(source);
    if (!isAvailable) {
      final available = await getAvailableDataSources();
      if (available.isNotEmpty) return available.first;
      return AirportDataSource.aviationApi;
    }
    return source;
  }

  Future<void> setDataSource(AirportDataSource source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dataSourceKey, source.name);
  }

  /// 重置 API 消耗计数
  Future<void> resetTokenCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tokenCountKey, 0);
  }

  /// 获取缓存的在线 API 数据
  Future<AirportDetailData?> getCachedOnlineDetail(String icaoCode) async {
    return _getCachedData(icaoCode, AirportDataSourceType.aviationApi);
  }

  /// 获取缓存的本地数据库数据
  Future<AirportDetailData?> getCachedLocalDetail(String icaoCode) async {
    final source = await getDataSource();
    if (source == AirportDataSource.aviationApi) {
      final lnm = await _getCachedData(icaoCode, AirportDataSourceType.lnmData);
      if (lnm != null) return lnm;
      return await _getCachedData(icaoCode, AirportDataSourceType.xplaneData);
    }
    return await _getCachedData(icaoCode, source.dataSourceType);
  }

  /// 获取机场详细信息（带缓存和气象）
  Future<AirportDetailData?> fetchAirportDetail(
    String icaoCode, {
    bool forceRefresh = false,
    AirportDataSource? preferredSource,
    AirportCacheScope cacheScope = AirportCacheScope.temporary,
  }) async {
    try {
      final source = preferredSource ?? await getDataSource();

      if (!forceRefresh) {
        final prefs = await SharedPreferences.getInstance();
        final expiryDays = prefs.getInt('airport_data_expiry') ?? 30;
        if (cacheScope == AirportCacheScope.persistent) {
          final cached = await _getCachedData(icaoCode, source.dataSourceType);
          if (cached != null && !cached.isExpired(expiryDays)) {
            return cached;
          }
        } else {
          final cached = _getTemporaryCachedData(
            icaoCode,
            source.dataSourceType,
            expiryDays,
          );
          if (cached != null) {
            return cached;
          }
        }
      }

      // 1. 从数据源获取基础数据
      AirportDetailData? data = await _fetchFromSource(icaoCode, source);

      // 补充名称（如果 API 返回的名称不详细）
      if (data != null &&
          (data.name == 'Unknown Airport' ||
              data.name.length <= icaoCode.length + 2)) {
        final localInfo = AirportsDatabase.findByIcao(icaoCode);
        if (localInfo != null && !localInfo.nameChinese.contains('未知')) {
          data = data.copyWith(name: localInfo.nameChinese);
        }
      }

      if (data != null) {
        data = await _fillMissingGeometry(icaoCode, data, source);
      }

      // 2. 同时获取气象报文，封装成完整机场数据
      if (data != null) {
        final weatherService = WeatherService();
        final metar = await weatherService.fetchMetar(icaoCode);
        data = data.copyWith(metar: metar, isCached: false);
        await _cacheData(icaoCode, data, cacheScope);
      }

      return data;
    } catch (e) {
      AppLogger.error('Error fetching airport detail for $icaoCode: $e');
      final source = preferredSource ?? await getDataSource();
      if (cacheScope == AirportCacheScope.persistent) {
        return await _getCachedData(icaoCode, source.dataSourceType);
      }
      return _getTemporaryCachedData(icaoCode, source.dataSourceType, null);
    }
  }

  Future<AirportDetailData> _fillMissingGeometry(
    String icaoCode,
    AirportDetailData data,
    AirportDataSource source,
  ) async {
    var result = data;

    // 检查是否具备跑道几何数据 (用于识别飞机是否在跑道上)
    bool hasRunwayGeometry = result.runways.any(
      (r) => r.leLat != null && r.heLat != null,
    );

    if (result.taxiways.isNotEmpty &&
        result.parkings.isNotEmpty &&
        hasRunwayGeometry) {
      return result;
    }

    final fallbackSources = <AirportDataSource>[
      AirportDataSource.lnmData,
      AirportDataSource.xplaneData,
    ];

    for (final candidate in fallbackSources) {
      if (candidate == source) continue;
      final available = await isDataSourceAvailable(candidate);
      if (!available) continue;

      final other = await _fetchFromSource(icaoCode, candidate);
      if (other == null) continue;

      // 使用 complementWith 合并数据，它会自动处理跑道、频率等的补充
      result = result.complementWith(other);

      // 更新几何状态检查
      hasRunwayGeometry = result.runways.any(
        (r) => r.leLat != null && r.heLat != null,
      );

      if (result.taxiways.isNotEmpty &&
          result.parkings.isNotEmpty &&
          hasRunwayGeometry) {
        break;
      }
    }

    return result;
  }

  /// 从指定数据源获取机场详细信息
  Future<AirportDetailData?> _fetchFromSource(
    String icaoCode,
    AirportDataSource source,
  ) async {
    switch (source) {
      case AirportDataSource.aviationApi:
        return await _fetchFromAviationApi(icaoCode);
      case AirportDataSource.xplaneData:
        return await _fetchFromXPlane(icaoCode);
      case AirportDataSource.lnmData:
        return await _fetchFromLNM(icaoCode);
    }
  }

  /// 从 Aviation API 获取数据
  Future<AirportDetailData?> _fetchFromAviationApi(String icaoCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_airportDbTokenKey);
      if (token == null || token.isEmpty) return null;

      final url = '$_aviationApiBase/$icaoCode?apiToken=$token';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['error'] != null) return null;

        final currentCount = prefs.getInt(_tokenCountKey) ?? 0;
        await prefs.setInt(_tokenCountKey, currentCount + 1);

        return _parseAviationApiResponse(icaoCode, json);
      }
      return null;
    } catch (e) {
      AppLogger.error('Aviation API error: $e');
      return null;
    }
  }

  /// 解析 Aviation API 响应
  AirportDetailData _parseAviationApiResponse(
    String icaoCode,
    Map<String, dynamic> json,
  ) {
    final runways = <RunwayInfo>[];
    if (json['runways'] != null) {
      for (final rwy in json['runways']) {
        runways.add(
          RunwayInfo(
            ident: rwy['ident'] ?? 'N/A',
            lengthFt: _toInt(rwy['length_ft']),
            widthFt: _toInt(rwy['width_ft']),
            surface: rwy['surface'],
            lighted: rwy['lighted'] == "1" || rwy['lighted'] == 1,
            closed: rwy['closed'] == "1" || rwy['closed'] == 1,
            leIdent: rwy['le_ident'],
            heIdent: rwy['he_ident'],
            leIls: rwy['le_ils'] != null
                ? IlsInfo(
                    freq: _toDouble(rwy['le_ils']['freq']),
                    course: _toInt(rwy['le_ils']['course']) ?? 0,
                  )
                : null,
            heIls: rwy['he_ils'] != null
                ? IlsInfo(
                    freq: _toDouble(rwy['he_ils']['freq']),
                    course: _toInt(rwy['he_ils']['course']) ?? 0,
                  )
                : null,
          ),
        );
      }
    }

    final navaids = <NavaidInfo>[];
    if (json['navaids'] != null) {
      for (final nav in json['navaids']) {
        final rawFreq = _toDouble(nav['frequency_khz']);
        final type = nav['type'] ?? 'UNK';
        double frequency = rawFreq;

        // Aviation API 返回的是 kHz。如果是 VOR/DME/ILS，通常显示为 MHz
        if (type.contains('VOR') ||
            type.contains('DME') ||
            type.contains('ILS') ||
            type.contains('TACAN')) {
          frequency = rawFreq / 1000.0;
        }

        navaids.add(
          NavaidInfo(
            ident: nav['ident'] ?? 'N/A',
            name: nav['name'] ?? 'N/A',
            type: type,
            frequency: frequency,
            latitude: _toDouble(nav['latitude_deg']),
            longitude: _toDouble(nav['longitude_deg']),
            elevation: _toInt(nav['elevation_ft']),
            channel: nav['dme_channel'],
          ),
        );
      }
    }

    final frequencies = <FrequencyInfo>[];
    if (json['freqs'] != null) {
      for (final freq in json['freqs']) {
        frequencies.add(
          FrequencyInfo(
            type: freq['type'] ?? 'UNK',
            frequency: _toDouble(freq['frequency_mhz']),
            description: freq['description'],
          ),
        );
      }
    }

    return AirportDetailData(
      icaoCode: icaoCode,
      iataCode: json['iata_code'],
      name: json['name'] ?? 'Unknown Airport',
      city: json['municipality'],
      country: json['iso_country'],
      latitude: _toDouble(json['latitude_deg']),
      longitude: _toDouble(json['longitude_deg']),
      elevation: _toInt(json['elevation_ft']),
      runways: runways,
      navaids: navaids,
      frequencies: AirportFrequencies(all: frequencies),
      fetchedAt: DateTime.now(),
      dataSource: AirportDataSourceType.aviationApi,
    );
  }

  /// 从 X-Plane 本地数据库读取
  Future<AirportDetailData?> _fetchFromXPlane(String icaoCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final earthNavPath = prefs.getString(_xplanePathKey);
      if (earthNavPath == null) return null;
      return await XPlaneAptDatParser.loadAirportByIcao(
        icaoCode: icaoCode,
        earthNavPath: earthNavPath,
      );
    } catch (e) {
      AppLogger.error('X-Plane data parse error: $e');
      return null;
    }
  }

  /// 从 Little Navmap 数据库读取
  Future<AirportDetailData?> _fetchFromLNM(String icaoCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lnmPath = prefs.getString(_lnmPathKey);
      if (lnmPath == null) return null;
      final dbFile = File(lnmPath);
      if (!await dbFile.exists()) return null;
      return await LNMDatabaseParser.parseAirport(dbFile, icaoCode);
    } catch (e) {
      AppLogger.error('LNM data parse error: $e');
      return null;
    }
  }

  String _getPrefix(AirportDataSourceType type) {
    switch (type) {
      case AirportDataSourceType.aviationApi:
        return _onlineCachePrefix;
      case AirportDataSourceType.xplaneData:
        return '${_localCachePrefix}xplane_';
      case AirportDataSourceType.lnmData:
        return '${_localCachePrefix}lnm_';
    }
  }

  Future<AirportDetailData?> _getCachedData(
    String icaoCode,
    AirportDataSourceType type,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = _getPrefix(type);
      final key = '$prefix$icaoCode';
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return AirportDetailData.fromJson(json);
      }
    } catch (e) {
      AppLogger.error('Error reading cached data for $icaoCode: $e');
    }
    return null;
  }

  AirportDetailData? _getTemporaryCachedData(
    String icaoCode,
    AirportDataSourceType type,
    int? expiryDays,
  ) {
    final key = _getCacheKey(icaoCode, type);
    final data = _temporaryCache[key];
    if (data == null) return null;
    if (expiryDays != null && data.isExpired(expiryDays)) {
      _temporaryCache.remove(key);
      return null;
    }
    return data;
  }

  Future<void> _cacheData(
    String icaoCode,
    AirportDetailData data,
    AirportCacheScope cacheScope,
  ) async {
    if (cacheScope == AirportCacheScope.temporary) {
      _setTemporaryCache(icaoCode, data);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = _getPrefix(data.dataSource);
      final key = '$prefix$icaoCode';
      final jsonString = jsonEncode(data.toJson());
      await prefs.setString(key, jsonString);
    } catch (e) {
      AppLogger.error('Error caching data for $icaoCode: $e');
    }
  }

  String _getCacheKey(String icaoCode, AirportDataSourceType type) {
    return '${_getPrefix(type)}$icaoCode';
  }

  void _setTemporaryCache(String icaoCode, AirportDetailData data) {
    final key = _getCacheKey(icaoCode, data.dataSource);
    _temporaryCache.remove(key);
    _temporaryCache[key] = data;
    if (_temporaryCache.length > _temporaryCacheLimit) {
      final oldestKey = _temporaryCache.keys.first;
      _temporaryCache.remove(oldestKey);
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// 获取所有可用机场列表
  Future<List<Map<String, dynamic>>> loadAllAirports({
    AirportDataSource? source,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final targetSource = source ?? await getDataSource();

    if (targetSource == AirportDataSource.lnmData) {
      final lnmPath = prefs.getString(_lnmPathKey);
      if (lnmPath != null && lnmPath.isNotEmpty) {
        final file = File(lnmPath);
        if (await file.exists()) {
          try {
            final airports = await LNMDatabaseParser.getAllAirports(file);
            if (airports.isNotEmpty) return airports;
          } catch (e) {
            AppLogger.error('Error loading airports from LNM: $e');
          }
        }
      }
    }

    if (targetSource == AirportDataSource.xplaneData ||
        targetSource == AirportDataSource.lnmData) {
      final xplanePath = prefs.getString(_xplanePathKey);
      if (xplanePath != null && xplanePath.isNotEmpty) {
        try {
          final aptPath = await XPlaneAptDatParser.resolveAptDatPath(
            xplanePath,
          );
          if (aptPath != null) {
            final file = File(aptPath);
            if (await file.exists()) {
              final airports = await XPlaneAptDatParser.getAllAirports(file);
              if (airports.isNotEmpty) return airports;
            }
          }
        } catch (e) {
          AppLogger.error('Error loading airports from X-Plane: $e');
        }
      }
    }
    return [];
  }

  /// 验证 Token
  Future<bool> validateToken(String token) async {
    if (token.isEmpty) return false;
    try {
      final url = '$_aviationApiBase/ZSSS?apiToken=$token';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['error'] == null;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 验证 LNM DB
  Future<bool> validateLnmDatabase(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    try {
      final db = sqlite3.open(path);
      try {
        final tables = db.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='airport'",
        );
        return tables.isNotEmpty;
      } finally {
        db.dispose();
      }
    } catch (e) {
      return false;
    }
  }

  /// 验证 X-Plane 导航数据
  Future<bool> validateXPlaneData(String path) async {
    try {
      final aptPath = await XPlaneAptDatParser.resolveAptDatPath(path);
      if (aptPath == null) return false;
      final file = File(aptPath);
      if (!await file.exists()) return false;
      final lines = await file
          .openRead(0, 1024)
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();
      if (lines.isEmpty) return false;
      return lines.first.trim() == 'I' || lines.first.trim() == '1000';
    } catch (e) {
      return false;
    }
  }

  /// 清除机场详细信息缓存
  Future<void> clearAirportCache({
    bool all = true,
    String? icao,
    AirportDataSourceType? type,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (all) {
      final keys = prefs.getKeys().where(
        (k) =>
            k.startsWith(_onlineCachePrefix) ||
            k.startsWith('${_localCachePrefix}xplane_') ||
            k.startsWith('${_localCachePrefix}lnm_'),
      );
      for (final key in keys) {
        await prefs.remove(key);
      }
    } else if (icao != null) {
      if (type == null || type == AirportDataSourceType.aviationApi) {
        await prefs.remove('$_onlineCachePrefix$icao');
      }
      if (type == null || type == AirportDataSourceType.xplaneData) {
        await prefs.remove('${_localCachePrefix}xplane_$icao');
      }
      if (type == null || type == AirportDataSourceType.lnmData) {
        await prefs.remove('${_localCachePrefix}lnm_$icao');
      }
    }
  }

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_onlineCachePrefix) ||
          key.startsWith('${_localCachePrefix}xplane_') ||
          key.startsWith('${_localCachePrefix}lnm_')) {
        await prefs.remove(key);
      }
    }
  }

  /// 清除气象缓存
  Future<void> clearMetarCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('metar_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// 获取数据库信息（包括 AIRAC 周期和过期信息）
  Future<Map<String, String>> getDatabaseInfo(
    String path,
    AirportDataSource source,
  ) async {
    final info = <String, String>{
      'path': path,
      'type': source.displayName,
      'airac': '未知',
      'expiry': '', // 过期日期
      'is_expired': 'false',
    };

    try {
      final file = File(path);
      final parentDir = file.parent;

      // 1. 优先尝试从 cycle_info.txt 获取信息 (LNM 和 X-Plane 通用)
      // LNM 通常在数据库同级目录，X-Plane 可能在同级或父级 (Custom Data)
      final possibleCycleFiles = [
        File('${parentDir.path}/cycle_info.txt'),
        if (source == AirportDataSource.xplaneData)
          File('${parentDir.parent.path}/cycle_info.txt'),
      ];

      for (final cycleFile in possibleCycleFiles) {
        if (await cycleFile.exists()) {
          final content = await cycleFile.readAsString();

          // 提取 AIRAC Cycle
          final cycleMatch = RegExp(
            r'AIRAC cycle\s*:\s*(\d+)',
            caseSensitive: false,
          ).firstMatch(content);
          if (cycleMatch != null) {
            info['airac'] = cycleMatch.group(1) ?? '未知';
          }

          // 提取有效期 (支持格式: Valid (from/to): 22/JAN/2026 - 19/FEB/2026)
          final validityMatch = RegExp(
            r'Valid\s*\(from/to\):\s*[^-\n]+-\s*(\d{1,2}/[A-Z]{3}/\d{4})',
            caseSensitive: false,
          ).firstMatch(content);

          if (validityMatch != null) {
            final expiryStr = validityMatch.group(1)!;
            info['expiry'] = expiryStr;

            // 判断是否过期
            try {
              final months = {
                'JAN': 1,
                'FEB': 2,
                'MAR': 3,
                'APR': 4,
                'MAY': 5,
                'JUN': 6,
                'JUL': 7,
                'AUG': 8,
                'SEP': 9,
                'OCT': 10,
                'NOV': 11,
                'DEC': 12,
              };
              final parts = expiryStr.split('/');
              if (parts.length == 3) {
                final day = int.parse(parts[0]);
                final month = months[parts[1].toUpperCase()] ?? 1;
                final year = int.parse(parts[2]);
                final expiryDate = DateTime(year, month, day);
                if (DateTime.now().isAfter(
                  expiryDate.add(const Duration(days: 1)),
                )) {
                  info['is_expired'] = 'true';
                }
              }
            } catch (_) {}
          } else {
            // 兼容旧格式: to 23 MAR 2023
            final oldExpiryMatch = RegExp(
              r'to\s+(\d{1,2}\s+[A-Z]{3}\s+\d{4})',
              caseSensitive: false,
            ).firstMatch(content);
            if (oldExpiryMatch != null) {
              final expiryStr = oldExpiryMatch.group(1)!;
              info['expiry'] = expiryStr;

              // 补充旧格式解析逻辑
              try {
                final months = {
                  'JAN': 1,
                  'FEB': 2,
                  'MAR': 3,
                  'APR': 4,
                  'MAY': 5,
                  'JUN': 6,
                  'JUL': 7,
                  'AUG': 8,
                  'SEP': 9,
                  'OCT': 10,
                  'NOV': 11,
                  'DEC': 12,
                };
                final parts = expiryStr.split(RegExp(r'\s+'));
                if (parts.length == 3) {
                  final day = int.parse(parts[0]);
                  final month = months[parts[1].toUpperCase()] ?? 1;
                  final year = int.parse(parts[2]);
                  final expiryDate = DateTime(year, month, day);
                  if (DateTime.now().isAfter(
                    expiryDate.add(const Duration(days: 1)),
                  )) {
                    info['is_expired'] = 'true';
                  }
                }
              } catch (_) {}
            }
          }

          if (info['airac'] != '未知') break;
        }
      }

      // 2. 如果没找到文件或信息，执行备选方案
      if (source == AirportDataSource.lnmData && info['airac'] == '未知') {
        final db = sqlite3.open(path);
        try {
          final metadataTables = db.select(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='metadata'",
          );
          if (metadataTables.isNotEmpty) {
            final columns = db
                .select("PRAGMA table_info(metadata)")
                .map((row) => row['name'].toString().toLowerCase())
                .toList();
            final keyCol = columns.contains('key')
                ? 'key'
                : (columns.contains('name') ? 'name' : null);
            final valueCol = columns.contains('value') ? 'value' : null;
            if (keyCol != null && valueCol != null) {
              final result = db.select(
                "SELECT $valueCol FROM metadata WHERE $keyCol = 'NavDataCycle'",
              );
              if (result.isNotEmpty) {
                info['airac'] = result.first[valueCol].toString();
              }
            }
          }
        } catch (e) {
          AppLogger.error('Error reading LNM metadata: $e');
        } finally {
          db.dispose();
        }
      } else if (source == AirportDataSource.xplaneData &&
          info['airac'] == '未知') {
        final lines = await file
            .openRead(0, 2048)
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .take(10)
            .toList();
        for (final line in lines) {
          if (line.contains('Cycle')) {
            final match = RegExp(r'Cycle\s+(\d+)').firstMatch(line);
            if (match != null) {
              info['airac'] = match.group(1)!;
              break;
            }
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error getting database info: $e');
    }

    return info;
  }

  /// 获取气象雷达的时间戳 (RainViewer)
  Future<int?> fetchWeatherRadarTimestamp() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.rainviewer.com/public/weather-maps.json'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> past = data['radar']['past'];
        if (past.isNotEmpty) {
          // 获取最新的时间戳
          return past.last['time'] as int;
        }
      }
    } catch (e) {
      AppLogger.error('Error fetching weather radar timestamp: $e');
    }
    return null;
  }
}
