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
    final lnm = await _getCachedData(icaoCode, AirportDataSourceType.lnmData);
    if (lnm != null) return lnm;
    return await _getCachedData(icaoCode, AirportDataSourceType.xplaneData);
  }

  /// 获取机场详细信息（带缓存和气象）
  Future<AirportDetailData?> fetchAirportDetail(
    String icaoCode, {
    bool forceRefresh = false,
    AirportDataSource? preferredSource,
  }) async {
    try {
      final source = preferredSource ?? await getDataSource();

      // 1. 检查对应空间的缓存
      if (!forceRefresh) {
        final prefs = await SharedPreferences.getInstance();
        final expiryDays = prefs.getInt('airport_data_expiry') ?? 30;
        final cached = await _getCachedData(icaoCode, source.dataSourceType);
        if (cached != null && !cached.isExpired(expiryDays)) {
          return cached;
        }
      }

      // 2. 从数据源获取基础数据
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

      // 3. 同时获取气象报文，封装成完整机场数据
      if (data != null) {
        final weatherService = WeatherService();
        final metar = await weatherService.fetchMetar(icaoCode);
        data = AirportDetailData(
          icaoCode: data.icaoCode,
          iataCode: data.iataCode,
          name: data.name,
          city: data.city,
          country: data.country,
          latitude: data.latitude,
          longitude: data.longitude,
          elevation: data.elevation,
          runways: data.runways,
          navaids: data.navaids,
          frequencies: data.frequencies,
          fetchedAt: data.fetchedAt,
          isCached: false,
          dataSource: data.dataSource,
          metar: metar,
        );
        // 4. 保存到各自的缓存空间
        await _cacheData(icaoCode, data);
      }

      return data;
    } catch (e) {
      AppLogger.error('Error fetching airport detail for $icaoCode: $e');
      final source = preferredSource ?? await getDataSource();
      return await _getCachedData(icaoCode, source.dataSourceType);
    }
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

  /// 获取对应来源的缓存前缀
  String _getPrefix(AirportDataSourceType type) {
    return type == AirportDataSourceType.aviationApi
        ? _onlineCachePrefix
        : _localCachePrefix;
  }

  /// 从缓存读取数据
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

  /// 保存数据到缓存
  Future<void> _cacheData(String icaoCode, AirportDetailData data) async {
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
            k.startsWith(_onlineCachePrefix) || k.startsWith(_localCachePrefix),
      );
      for (final key in keys) {
        await prefs.remove(key);
      }
    } else if (icao != null) {
      if (type == null || type == AirportDataSourceType.aviationApi) {
        await prefs.remove('$_onlineCachePrefix$icao');
      }
      if (type == null || type != AirportDataSourceType.aviationApi) {
        await prefs.remove('$_localCachePrefix$icao');
      }
    }
  }

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_onlineCachePrefix) ||
          key.startsWith(_localCachePrefix)) {
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
}
