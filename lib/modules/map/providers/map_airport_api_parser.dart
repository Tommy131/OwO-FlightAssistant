import '../../airport_search/models/airport_search_models.dart';
import '../models/map_airport.dart';
import '../models/map_coordinate.dart';
import 'map_geo_utils.dart';
import 'map_weather_utils.dart';

/// 机场 API 数据解析工具类
///
/// 将后端 HTTP 响应（Map/List 形式的 JSON 数据）转换为业务模型，
/// 包括：
/// - [MapAirportMarker] — 从搜索/边框查询结果中提取标记点
/// - [MapRunwayGeometry] — 从机场布局数据中提取跑道几何
/// - [MapParkingSpot] — 从机场停机位数据中提取停机点
///
/// 所有方法均为静态纯函数，可在 [MapProvider] 中直接调用，也可在测试中单独使用。
class MapAirportApiParser {
  MapAirportApiParser._(); // 纯工具类，禁止实例化

  // ── 标记点解析 ────────────────────────────────────────────────────────────

  /// 从 API 返回的原始 Map 解析出 [MapAirportMarker]
  ///
  /// 尝试多个键名组合提取 ICAO 码、名称、坐标，
  /// 当 API 坐标无效时使用 [fallbackAirports] 中同 ICAO 机场的坐标兜底。
  static MapAirportMarker airportMarkerFromApi(
    Map<String, dynamic> raw, {
    List<MapAirportMarker> fallbackAirports = const [],
  }) {
    final code =
        (raw['icao'] ?? raw['ICAO'] ?? raw['iata'] ?? raw['IATA'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
    final name = (raw['name'] ?? raw['Name'])?.toString().trim();
    final lat = _extractLatitude(raw);
    final lon = _extractLongitude(raw);

    // 找同 ICAO 的兜底机场（用于坐标无效时回退）
    final fallback = _findAirportByCode(code, fallbackAirports);
    final fallbackLat = fallback?.position.latitude;
    final fallbackLon = fallback?.position.longitude;

    // 优先使用 API 坐标，无效时回退到兜底，最终默认 (0, 0)
    final resolvedLat =
        lat != null && lon != null && MapGeoUtils.isValidCoordinate(lat, lon)
        ? lat
        : (fallbackLat != null &&
                  fallbackLon != null &&
                  MapGeoUtils.isValidCoordinate(fallbackLat, fallbackLon)
              ? fallbackLat
              : 0.0);
    final resolvedLon =
        lat != null && lon != null && MapGeoUtils.isValidCoordinate(lat, lon)
        ? lon
        : (fallbackLat != null &&
                  fallbackLon != null &&
                  MapGeoUtils.isValidCoordinate(fallbackLat, fallbackLon)
              ? fallbackLon
              : 0.0);

    return MapAirportMarker(
      code: code,
      name: name?.isEmpty ?? true ? null : name,
      position: MapCoordinate(latitude: resolvedLat, longitude: resolvedLon),
      isPrimary: false,
    );
  }

  // ── 跑道几何解析 ──────────────────────────────────────────────────────────

  /// 将机场跑道数据 [AirportRunwayData] 转换为 [MapRunwayGeometry]
  ///
  /// 当起点或终点坐标无效时返回 null（跳过该跑道）。
  static MapRunwayGeometry? toRunwayGeometry(AirportRunwayData data) {
    final startLat = data.leLat;
    final startLon = data.leLon;
    final endLat = data.heLat;
    final endLon = data.heLon;

    if (startLat == null ||
        startLon == null ||
        endLat == null ||
        endLon == null) {
      return null;
    }
    if (!MapGeoUtils.isValidCoordinate(startLat, startLon) ||
        !MapGeoUtils.isValidCoordinate(endLat, endLon)) {
      return null;
    }

    final leIdent = resolveRunwayEndIdent(data.ident, data.leIdent, true);
    final heIdent = resolveRunwayEndIdent(data.ident, data.heIdent, false);
    return MapRunwayGeometry(
      ident: data.ident,
      leIdent: leIdent,
      heIdent: heIdent,
      start: MapCoordinate(latitude: startLat, longitude: startLon),
      end: MapCoordinate(latitude: endLat, longitude: endLon),
      lengthM: data.lengthM,
    );
  }

  // ── 停机位解析 ────────────────────────────────────────────────────────────

  /// 将停机位数据 [AirportParkingData] 转换为 [MapParkingSpot]
  ///
  /// 坐标无效时返回 null（跳过该停机位）。
  static MapParkingSpot? toParkingSpot(AirportParkingData data) {
    final lat = data.latitude;
    final lon = data.longitude;
    if (lat == null || lon == null) return null;
    if (!MapGeoUtils.isValidCoordinate(lat, lon)) return null;
    return MapParkingSpot(
      name: data.name,
      position: MapCoordinate(latitude: lat, longitude: lon),
      headingDeg: data.headingDeg,
    );
  }

  // ── 跑道标识符标准化 ──────────────────────────────────────────────────────

  /// 标准化跑道复合标识符（如 "09/27" → "09" 或 "27"）
  ///
  /// 支持带后缀的格式（如 "09L/27R"）。
  static String normalizeRunwayIdent(String ident) {
    final text = ident.trim().toUpperCase();
    if (text.isEmpty) return '';
    final pairMatch = RegExp(r'(\d{2}[LCR]?/\d{2}[LCR]?)').firstMatch(text);
    if (pairMatch != null) return pairMatch.group(1) ?? '';
    final singleMatch = RegExp(r'\d{2}[LCR]?').firstMatch(text);
    return singleMatch?.group(0) ?? text;
  }

  /// 解析跑道端头标识符
  ///
  /// 若 [endpoint] 字段有值则直接返回（大写），
  /// 否则从 [ident]（如 "09/27"）中按 [isLeft] 提取对应的半边。
  static String? resolveRunwayEndIdent(
    String ident,
    String? endpoint,
    bool isLeft,
  ) {
    final direct = endpoint?.trim();
    if (direct != null && direct.isNotEmpty) return direct.toUpperCase();
    final normalized = ident.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final parts = normalized.split('/');
    if (parts.length == 2) {
      return isLeft ? parts[0].trim() : parts[1].trim();
    }
    return normalized;
  }

  // ── 机场中心坐标推断 ──────────────────────────────────────────────────────

  /// 从跑道几何列表推断机场参考中心坐标
  ///
  /// 策略（优先级降序）：
  /// 1. 以各跑道中点的加权平均值（以跑道长度为权重）作为中心
  /// 2. 使用 API 返回的机场坐标字段
  /// 3. 使用 [fallback] 兜底坐标
  static MapCoordinate resolveAirportCenter(
    List<MapRunwayGeometry> runways,
    double? latitude,
    double? longitude,
    MapCoordinate fallback,
  ) {
    if (runways.isNotEmpty) {
      double latSum = 0;
      double lonSum = 0;
      double weightSum = 0;
      for (final runway in runways) {
        final midLat = (runway.start.latitude + runway.end.latitude) / 2;
        final midLon = (runway.start.longitude + runway.end.longitude) / 2;
        // 以跑道长度为权重，未知长度时权重为 1.0
        final weight = runway.lengthM != null && runway.lengthM! > 0
            ? runway.lengthM!
            : 1.0;
        latSum += midLat * weight;
        lonSum += midLon * weight;
        weightSum += weight;
      }
      if (weightSum > 0) {
        final candidateLat = latSum / weightSum;
        final candidateLon = lonSum / weightSum;
        if (MapGeoUtils.isValidCoordinate(candidateLat, candidateLon)) {
          return MapCoordinate(latitude: candidateLat, longitude: candidateLon);
        }
      }
    }
    if (latitude != null &&
        longitude != null &&
        MapGeoUtils.isValidCoordinate(latitude, longitude)) {
      return MapCoordinate(latitude: latitude, longitude: longitude);
    }
    return fallback;
  }

  // ── 私有辅助方法 ──────────────────────────────────────────────────────────

  /// 从原始 Map 提取纬度（支持多个键名及嵌套结构）
  static double? _extractLatitude(Map<String, dynamic> raw) {
    final direct = _toDouble(
      MapWeatherUtils.pickValue(raw, [
        'latitude',
        'lat',
        'Lat',
        'Latitude',
        'y',
      ]),
    );
    if (direct != null) return direct;
    for (final key in ['location', 'position', 'coordinate', 'coordinates']) {
      final nested = MapWeatherUtils.asMap(
        MapWeatherUtils.pickValue(raw, [key]),
      );
      final value = _toDouble(
        MapWeatherUtils.pickValue(nested ?? const {}, [
          'latitude',
          'lat',
          'Lat',
          'y',
        ]),
      );
      if (value != null) return value;
    }
    // 尝试 GeoJSON geometry.coordinates[1]（WGS-84 规范：lon, lat）
    final geometry = MapWeatherUtils.asMap(
      MapWeatherUtils.pickValue(raw, ['geometry', 'geojson']),
    );
    final coordinates = _asList(
      MapWeatherUtils.pickValue(geometry ?? const {}, ['coordinates']),
    );
    if (coordinates != null && coordinates.length >= 2) {
      return _toDouble(coordinates[1]);
    }
    return null;
  }

  /// 从原始 Map 提取经度（支持多个键名及嵌套结构）
  static double? _extractLongitude(Map<String, dynamic> raw) {
    final direct = _toDouble(
      MapWeatherUtils.pickValue(raw, [
        'longitude',
        'lon',
        'lng',
        'Lon',
        'Lng',
        'x',
      ]),
    );
    if (direct != null) return direct;
    for (final key in ['location', 'position', 'coordinate', 'coordinates']) {
      final nested = MapWeatherUtils.asMap(
        MapWeatherUtils.pickValue(raw, [key]),
      );
      final value = _toDouble(
        MapWeatherUtils.pickValue(nested ?? const {}, [
          'longitude',
          'lon',
          'lng',
          'Lon',
          'Lng',
          'x',
        ]),
      );
      if (value != null) return value;
    }
    final geometry = MapWeatherUtils.asMap(
      MapWeatherUtils.pickValue(raw, ['geometry', 'geojson']),
    );
    final coordinates = _asList(
      MapWeatherUtils.pickValue(geometry ?? const {}, ['coordinates']),
    );
    if (coordinates != null && coordinates.length >= 2) {
      return _toDouble(coordinates[0]);
    }
    return null;
  }

  /// 将任意值安全转换为 double
  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  /// 将任意值安全转换为 List<dynamic>
  static List<dynamic>? _asList(dynamic value) {
    if (value is List<dynamic>) return value;
    if (value is List) return value.cast<dynamic>();
    return null;
  }

  /// 从机场列表中按 ICAO 码查找第一个匹配机场
  static MapAirportMarker? _findAirportByCode(
    String code,
    List<MapAirportMarker> airports,
  ) {
    for (final airport in airports) {
      if (airport.code.toUpperCase() == code.toUpperCase()) return airport;
    }
    return null;
  }
}
