import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mock_airport_database.dart';
import '../models/airport_detail_data.dart';

/// 数据源类型
enum AirportDataSource {
  aviationApi, // 免费API (airportdb.io)
  xplaneData, // X-Plane导航数据
  msfsData, // MSFS导航数据
  mockData, // 模拟数据
}

extension AirportDataSourceExtension on AirportDataSource {
  String get displayName {
    switch (this) {
      case AirportDataSource.aviationApi:
        return '在线API (airportdb.io)';
      case AirportDataSource.xplaneData:
        return 'X-Plane 导航数据';
      case AirportDataSource.msfsData:
        return 'MSFS 导航数据';
      case AirportDataSource.mockData:
        return '模拟数据';
    }
  }

  AirportDataSourceType get dataSourceType {
    switch (this) {
      case AirportDataSource.aviationApi:
        return AirportDataSourceType.aviationApi;
      case AirportDataSource.xplaneData:
        return AirportDataSourceType.xplaneData;
      case AirportDataSource.msfsData:
        return AirportDataSourceType.msfsData;
      case AirportDataSource.mockData:
        return AirportDataSourceType.mockData;
    }
  }
}

/// 机场详细信息服务
/// 支持多种数据源：免费API、X-Plane、MSFS、模拟数据
class AirportDetailService {
  static const String _cachePrefix = 'airport_detail_';
  static const String _dataSourceKey = 'airport_data_source';

  // Aviation API (免费，无需API key)
  static const String _aviationApiBase = 'https://airportdb.io/api/v1/airport';

  /// 获取当前数据源设置
  Future<AirportDataSource> getDataSource() async {
    final prefs = await SharedPreferences.getInstance();
    final sourceStr = prefs.getString(_dataSourceKey);

    if (sourceStr != null) {
      return AirportDataSource.values.firstWhere(
        (s) => s.name == sourceStr,
        orElse: () => AirportDataSource.aviationApi,
      );
    }

    return AirportDataSource.aviationApi;
  }

  /// 设置数据源
  Future<void> setDataSource(AirportDataSource source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dataSourceKey, source.name);
  }

  /// 获取机场详细信息（带缓存）
  Future<AirportDetailData?> fetchAirportDetail(
    String icaoCode, {
    bool forceRefresh = false,
    AirportDataSource? preferredSource,
  }) async {
    try {
      // 1. 检查缓存（除非强制刷新）
      if (!forceRefresh) {
        final cached = await _getCachedData(icaoCode);
        if (cached != null && !cached.isExpired) {
          return cached;
        }
      }

      // 2. 确定数据源
      final source = preferredSource ?? await getDataSource();

      // 3. 从数据源获取数据
      final freshData = await _fetchFromSource(icaoCode, source);

      // 4. 保存到缓存
      if (freshData != null) {
        await _cacheData(icaoCode, freshData);
      }

      return freshData;
    } catch (e) {
      print('Error fetching airport detail for $icaoCode: $e');
      // 如果失败，尝试返回缓存数据（即使过期）
      return await _getCachedData(icaoCode);
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
        // TODO: 实现X-Plane导航数据读取
        print('X-Plane data source not yet implemented, using mock data');
        return _fetchFromMockData(icaoCode);
      case AirportDataSource.msfsData:
        // TODO: 实现MSFS导航数据读取
        print('MSFS data source not yet implemented, using mock data');
        return _fetchFromMockData(icaoCode);
      case AirportDataSource.mockData:
        return _fetchFromMockData(icaoCode);
    }
  }

  /// 从 Aviation API 获取数据
  Future<AirportDetailData?> _fetchFromAviationApi(String icaoCode) async {
    try {
      final url = '$_aviationApiBase/$icaoCode';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return _parseAviationApiResponse(icaoCode, json);
      } else {
        print(
          'Aviation API returned ${response.statusCode}, falling back to mock',
        );
        return _fetchFromMockData(icaoCode);
      }
    } catch (e) {
      print('Aviation API error: $e, falling back to mock');
      return _fetchFromMockData(icaoCode);
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
            lengthFt: rwy['length_ft']?.toInt(),
            widthFt: rwy['width_ft']?.toInt(),
            surface: rwy['surface'],
            lighted: rwy['lighted'],
            closed: rwy['closed'],
            le_ident: rwy['le_ident'],
            he_ident: rwy['he_ident'],
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
            frequency: (freq['frequency_mhz'] ?? 0.0).toDouble(),
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
      latitude: (json['latitude_deg'] ?? 0.0).toDouble(),
      longitude: (json['longitude_deg'] ?? 0.0).toDouble(),
      elevation: json['elevation_ft']?.toInt(),
      runways: runways,
      frequencies: AirportFrequencies(all: frequencies),
      fetchedAt: DateTime.now(),
      dataSource: AirportDataSourceType.aviationApi,
    );
  }

  /// 从模拟数据库获取数据
  AirportDetailData? _fetchFromMockData(String icaoCode) {
    return MockAirportDatabase.getAirportData(icaoCode);
  }

  /// 从缓存读取数据
  Future<AirportDetailData?> _getCachedData(String icaoCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cachePrefix$icaoCode';
      final jsonString = prefs.getString(key);

      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return AirportDetailData.fromJson(json);
      }
    } catch (e) {
      print('Error reading cached data for $icaoCode: $e');
    }
    return null;
  }

  /// 保存数据到缓存
  Future<void> _cacheData(String icaoCode, AirportDetailData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cachePrefix$icaoCode';
      final jsonString = jsonEncode(data.toJson());
      await prefs.setString(key, jsonString);
    } catch (e) {
      print('Error caching data for $icaoCode: $e');
    }
  }

  /// 清除特定机场的缓存
  Future<void> clearCache(String icaoCode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cachePrefix$icaoCode';
    await prefs.remove(key);
  }

  /// 清除所有机场缓存
  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_cachePrefix)) {
        await prefs.remove(key);
      }
    }
  }
}
