import '../../../common/models/common_models.dart';
import '../../../http/http_module.dart';
import '../../models/map_models.dart';

/// 机场数据组件（数据聚合类型）
///
/// 仅负责机场列表构建、本地兜底查询与 ICAO 索引，不处理 UI 与网络副作用。
class MapAirportDataComponent {
  MapAirportDataComponent._();

  /// 从首页快照构建地图机场标记列表，并按 ICAO 去重。
  static List<MapAirportMarker> buildAirportsFromSnapshot(
    HomeDataSnapshot snapshot,
  ) {
    final result = <MapAirportMarker>[];
    final added = <String>{};

    void addAirport(HomeAirportInfo? airport, {required bool isPrimary}) {
      if (airport == null) return;
      final code = airport.icaoCode.trim().toUpperCase();
      if (code.isEmpty || added.contains(code)) return;
      added.add(code);
      result.add(
        MapAirportMarker(
          code: code,
          name: airport.displayName,
          position: MapCoordinate(
            latitude: airport.latitude,
            longitude: airport.longitude,
          ),
          isPrimary: isPrimary,
        ),
      );
    }

    addAirport(snapshot.nearestAirport, isPrimary: true);
    addAirport(snapshot.destinationAirport, isPrimary: true);
    addAirport(snapshot.alternateAirport, isPrimary: false);
    for (final airport in snapshot.suggestedAirports) {
      addAirport(airport, isPrimary: false);
    }
    return result;
  }

  /// 当接口不可用时，以内存中的机场列表执行关键字查询。
  static List<MapAirportMarker> fallbackSearchAirports(
    String keyword,
    List<MapAirportMarker> airports,
  ) {
    final query = keyword.toLowerCase();
    return airports.where((airport) {
      final name = airport.name?.toLowerCase() ?? '';
      return airport.code.toLowerCase().contains(query) || name.contains(query);
    }).toList();
  }

  /// 通过 ICAO 精确查找机场，大小写不敏感。
  static MapAirportMarker? findAirportByCode(
    String code,
    List<MapAirportMarker> airports,
  ) {
    for (final airport in airports) {
      if (airport.code.toUpperCase() == code.toUpperCase()) {
        return airport;
      }
    }
    return null;
  }

  /// 拉取机场详情布局，如失败则自动回退到基础机场详情接口。
  static Future<Map<String, dynamic>> fetchAirportLayoutByIcao(
    String icao,
  ) async {
    await HttpModule.client.init();
    try {
      final layoutResponse = await HttpModule.client.getAirportLayoutByIcao(
        icao,
      );
      return _asMap(layoutResponse.decodedBody) ?? const {};
    } catch (_) {
      final fallbackResponse = await HttpModule.client.getAirportByIcao(icao);
      return _asMap(fallbackResponse.decodedBody) ?? const {};
    }
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry('$k', v));
    return null;
  }
}
