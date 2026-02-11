import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';
import '../../core/services/persistence/persistence_service.dart';
import '../models/airport_detail_data.dart';
import '../data/xplane_apt_dat_parser.dart';
import '../data/lnm_database_parser.dart';
import '../data/airports_database.dart';
import 'weather_service.dart';
import 'app_core/database_loader.dart';

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
  static const String _airportDbTokenKey = 'airportdb_token';
  static const String _tokenThresholdKey = 'token_consumption_threshold';
  static const String _tokenCountKey = 'token_consumption_count';

  // Aviation API (免费，无需API key)
  static const String _aviationApiBase = 'https://airportdb.io/api/v1/airport';
  static const int _temporaryCacheLimit = 200;

  final Map<String, AirportDetailData> _temporaryCache = {};
  final PersistenceService _persistence = PersistenceService();
  final DatabaseSettingsService _settings = DatabaseSettingsService();
  final DatabaseLoader _databaseLoader = DatabaseLoader();

  /// 检查特定数据源是否可用（已配置）
  Future<bool> isDataSourceAvailable(AirportDataSource source) async {
    await _settings.ensureSynced();
    switch (source) {
      case AirportDataSource.aviationApi:
        final token = await _settings.getString(_airportDbTokenKey);
        if (token == null || token.isEmpty) return false;
        final threshold =
            await _settings.getInt(_tokenThresholdKey) ?? 5000;
        final count = await _settings.getInt(_tokenCountKey) ?? 0;
        return count < threshold;
      case AirportDataSource.xplaneData:
        final aptPath = await _databaseLoader.resolveXPlaneAptPath();
        return aptPath != null && aptPath.isNotEmpty;
      case AirportDataSource.lnmData:
        final lnmPath = await _databaseLoader.resolveLnmPath();
        return lnmPath != null && lnmPath.isNotEmpty;
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
    final sourceStr = await _settings.getString(_dataSourceKey);
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
    await _settings.setString(_dataSourceKey, source.name);
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
      await _settings.ensureSynced();
      final source = preferredSource ?? await getDataSource();

      if (!forceRefresh) {
        final expiryDays =
            await _settings.getInt(DatabaseSettingsService.airportExpiryKey) ??
                30;
        if (cacheScope == AirportCacheScope.persistent) {
          final cached = await _getCachedData(icaoCode, source.dataSourceType);
          if (cached != null && !cached.isExpired(expiryDays)) {
            AppLogger.info('命中机场缓存: $icaoCode (${source.name}) persistent');
            return cached;
          }
        } else {
          final cached = _getTemporaryCachedData(
            icaoCode,
            source.dataSourceType,
            expiryDays,
          );
          if (cached != null) {
            AppLogger.info('命中机场缓存: $icaoCode (${source.name}) temporary');
            return cached;
          }
        }
      }

      // 1. 从数据源获取基础数据
      AppLogger.info('加载机场数据: $icaoCode (${source.name})');
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
        AppLogger.info('机场数据缓存完成: $icaoCode (${source.name})');
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
      final token = await _settings.getString(_airportDbTokenKey);
      if (token == null || token.isEmpty) {
        AppLogger.warning('Aviation API token 未配置');
        return null;
      }

      final url = '$_aviationApiBase/$icaoCode?apiToken=$token';
      AppLogger.info('请求机场 API: $icaoCode');
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['error'] != null) return null;

        final currentCount = await _settings.getInt(_tokenCountKey) ?? 0;
        await _settings.setInt(_tokenCountKey, currentCount + 1);

        return _parseAviationApiResponse(icaoCode, json);
      }
      AppLogger.warning('机场 API 请求失败: $icaoCode (HTTP ${response.statusCode})');
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
      final aptPath = await _databaseLoader.resolveXPlaneAptPath();
      if (aptPath == null) {
        AppLogger.warning('X-Plane 数据路径未配置');
        return null;
      }
      AppLogger.debug('从 X-Plane 加载机场: $icaoCode (路径: $aptPath)');
      return await XPlaneAptDatParser.loadAirportFromAptPath(
        icaoCode: icaoCode,
        aptPath: aptPath,
      );
    } catch (e) {
      AppLogger.error('X-Plane data parse error: $e');
      return null;
    }
  }

  /// 从 Little Navmap 数据库读取
  Future<AirportDetailData?> _fetchFromLNM(String icaoCode) async {
    try {
      final lnmPath = await _databaseLoader.resolveLnmPath();
      if (lnmPath == null) {
        AppLogger.warning('LNM 数据路径未配置');
        return null;
      }
      final dbFile = File(lnmPath);
      if (!await dbFile.exists()) {
        AppLogger.error('LNM 数据库文件不存在: $lnmPath');
        return null;
      }
      AppLogger.debug('从 LNM 加载机场: $icaoCode (路径: $lnmPath)');
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
      final prefix = _getPrefix(type);
      final key = '$prefix$icaoCode';
      final jsonString = _persistence.getString(key);
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
      final prefix = _getPrefix(data.dataSource);
      final key = '$prefix$icaoCode';
      final jsonString = jsonEncode(data.toJson());
      await _persistence.setString(key, jsonString);
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
    await _settings.ensureSynced();
    final targetSource = source ?? await getDataSource();

    if (targetSource == AirportDataSource.lnmData) {
      final lnmAirports = await _databaseLoader.loadAllAirports(
        AirportDataSourceType.lnmData,
      );
      if (lnmAirports.isNotEmpty) return lnmAirports;
    }

    if (targetSource == AirportDataSource.xplaneData ||
        targetSource == AirportDataSource.lnmData) {
      final xplaneAirports = await _databaseLoader.loadAllAirports(
        AirportDataSourceType.xplaneData,
      );
      if (xplaneAirports.isNotEmpty) return xplaneAirports;
    }
    return [];
  }

  /// 清除机场详细信息缓存
  Future<void> clearAirportCache({
    bool all = true,
    String? icao,
    AirportDataSourceType? type,
  }) async {
    if (all) {
      // 清除所有缓存键
      // 注意: PersistenceService 目前不支持 getKeys，需要手动清除已知的缓存
      _temporaryCache.clear();
      AppLogger.info('已清除所有临时缓存');
    } else if (icao != null) {
      if (type == null || type == AirportDataSourceType.aviationApi) {
        await _persistence.remove('$_onlineCachePrefix$icao');
      }
      if (type == null || type == AirportDataSourceType.xplaneData) {
        await _persistence.remove('${_localCachePrefix}xplane_$icao');
      }
      if (type == null || type == AirportDataSourceType.lnmData) {
        await _persistence.remove('${_localCachePrefix}lnm_$icao');
      }
      _temporaryCache.remove(
        _getCacheKey(icao, type ?? AirportDataSourceType.aviationApi),
      );
    }
  }

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    _temporaryCache.clear();
    AppLogger.info('已清除所有缓存');
  }

  /// 获取气象雷达的时间戳 (RainViewer)
  Future<int?> fetchWeatherRadarTimestamp() async {
    try {
      AppLogger.info('请求气象雷达时间戳');
      final response = await http.get(
        Uri.parse('https://api.rainviewer.com/public/weather-maps.json'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> past = data['radar']['past'];
        if (past.isNotEmpty) {
          // 获取最新的时间戳
          AppLogger.info('气象雷达时间戳获取成功');
          return past.last['time'] as int;
        }
        AppLogger.warning('气象雷达时间戳为空');
      } else {
        AppLogger.warning('气象雷达请求失败 (HTTP ${response.statusCode})');
      }
    } catch (e) {
      AppLogger.error('Error fetching weather radar timestamp: $e');
    }
    return null;
  }
}
