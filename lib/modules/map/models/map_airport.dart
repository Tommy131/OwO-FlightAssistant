import 'map_coordinate.dart';

/// 机场标记点（地图图钉）
///
/// 代表地图上一个机场的简要信息，用于渲染图钉、搜索结果、建议列表等。
class MapAirportMarker {
  /// ICAO/IATA 机场代码（大写，如 "EDDF"）
  final String code;

  /// 机场名称（可选，如 "Frankfurt Airport"）
  final String? name;

  /// 机场参考坐标（WGS-84）
  final MapCoordinate position;

  /// 是否为主要机场（起飞/降落机场）
  final bool isPrimary;

  const MapAirportMarker({
    required this.code,
    required this.position,
    this.name,
    this.isPrimary = false,
  });
}

/// 跑道几何数据（用于在地图上绘制跑道线段）
class MapRunwayGeometry {
  /// 跑道标识符（如 "09/27" 或 "09L/27R"）
  final String ident;

  /// 低端（LE）跑道号（如 "09L"，可选）
  final String? leIdent;

  /// 高端（HE）跑道号（如 "27R"，可选）
  final String? heIdent;

  /// 跑道低端坐标（LE threshold）
  final MapCoordinate start;

  /// 跑道高端坐标（HE threshold）
  final MapCoordinate end;

  /// 跑道长度（米，可选）
  final double? lengthM;

  const MapRunwayGeometry({
    required this.ident,
    required this.start,
    required this.end,
    this.leIdent,
    this.heIdent,
    this.lengthM,
  });
}

/// 停机位数据
class MapParkingSpot {
  /// 停机位编号/名称（可选，如 "A1"）
  final String? name;

  /// 停机位中心坐标
  final MapCoordinate position;

  /// 停机朝向（度，可选，0 = 正北）
  final double? headingDeg;

  const MapParkingSpot({
    this.name,
    required this.position,
    this.headingDeg,
  });
}

/// 选中机场的完整详情数据
///
/// 在用户点击地图上某机场图钉后，由 [MapProvider.fetchSelectedAirportDetail]
/// 从后端 API 拉取，包含跑道几何、停机位、天气（METAR）及通信频率等信息。
class MapSelectedAirportDetail {
  /// 机场简要标记（代码、名称、坐标）
  final MapAirportMarker marker;

  /// 数据来源标识（API 名称/版本，可选）
  final String? source;

  /// 跑道标识符列表（如 ["09/27", "15/33"]）
  final List<String> runways;

  /// 跑道几何列表（用于地图上绘制跑道线段）
  final List<MapRunwayGeometry> runwayGeometries;

  /// 停机位列表（用于地图上渲染停机位图标）
  final List<MapParkingSpot> parkingSpots;

  /// 通信频率徽章列表（如 ["ATIS: 127.15", "TWR: 118.7"]，最多 4 条）
  final List<String> frequencyBadges;

  /// ATIS 播报文字（可选）
  final String? atis;

  /// 原始 METAR 报文（可选）
  final String? rawMetar;

  /// 解析后的 METAR 描述（人类可读，可选）
  final String? decodedMetar;

  /// 飞行规则分类（如 "VFR"、"IFR"、"MVFR"、"LIFR"，可选）
  final String? approachRule;

  const MapSelectedAirportDetail({
    required this.marker,
    this.source,
    this.runways = const [],
    this.runwayGeometries = const [],
    this.parkingSpots = const [],
    this.frequencyBadges = const [],
    this.atis,
    this.rawMetar,
    this.decodedMetar,
    this.approachRule,
  });
}
