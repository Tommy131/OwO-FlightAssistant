import 'model_utils.dart';
import 'airport_runway_data.dart';
import 'airport_parking_data.dart';
import 'airport_frequency_data.dart';

/// 机场详细信息完整模型
/// 该模型包含机场的基本信息、跑道、停机位以及频率等子项
class AirportDetailData {
  /// 原始完整的 API Payload 数据，用于调试或后续扩展
  final Map<String, dynamic> payload;

  /// 机场 ICAO 代码 (如: ZGGG, VHHH)
  final String icao;

  /// 机场 IATA 代码 (如: CAN, HKG)
  final String? iata;

  /// 机场名称
  final String? name;

  /// 所在城市
  final String? city;

  /// 所在国家
  final String? country;

  /// 经纬度
  final double? latitude;
  final double? longitude;

  /// 海拔高度 (以英尺为单位)
  final int? elevationFt;

  /// 数据库来源 (如: MSFS, Navigraph)
  final String? source;

  /// 数据周期号 (如: 2311)
  final String? airac;

  /// 跑道列表
  final List<AirportRunwayData> runways;

  /// 停机位列表
  final List<AirportParkingData> parkings;

  /// 通讯频率列表
  final List<AirportFrequencyData> frequencies;

  const AirportDetailData({
    required this.payload,
    required this.icao,
    this.iata,
    this.name,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.elevationFt,
    this.source,
    this.airac,
    this.runways = const [],
    this.parkings = const [],
    this.frequencies = const [],
  });

  /// 从 API 响应数据中构建完整的机场详情
  /// 支持多种常见的 JSON 结构解析 (Navigraph, SimBrief, OWO Middleware 等)
  factory AirportDetailData.fromApi(Map<String, dynamic> data) {
    // 尝试寻找根节点
    final payloadRoot = asMap(pick(data, ['data'])) ?? data;

    // 寻找机场详情子节点
    var detail = asMap(
      pick(payloadRoot, ['airport_detail', 'airportDetail', 'AirportDetail']),
    );

    // 自动兼容没有外层 detail 封装的结构
    if (detail == null &&
        (pick(payloadRoot, ['airport', 'Airport']) != null ||
            pick(payloadRoot, ['sources', 'Sources']) != null)) {
      detail = payloadRoot;
    }

    final airport = asMap(pick(detail, ['airport', 'Airport']));

    // 解析跑道数据
    final runways = asListOfMaps(
      pick(detail, ['runways', 'Runways']),
    ).map(AirportRunwayData.fromApi).toList();

    // 解析停机位数据
    final parkings = asListOfMaps(
      pick(detail, [
        'parkings',
        'Parkings',
        'parking_spots',
        'parkingSpots',
        'parking_points',
      ]),
    ).map(AirportParkingData.fromApi).toList();

    // 解析频率数据
    final frequencies = asListOfMaps(
      pick(detail, ['frequencies', 'Frequencies']),
    ).map(AirportFrequencyData.fromApi).toList();

    final icao =
        readString(pick(airport, ['icao', 'ICAO'])) ??
        readString(pick(detail, ['icao', 'ICAO'])) ??
        readString(pick(payloadRoot, ['icao', 'ICAO'])) ??
        '';

    return AirportDetailData(
      payload: Map<String, dynamic>.from(data),
      icao: icao.toUpperCase(),
      iata: readString(pick(airport, ['iata', 'IATA'])),
      name:
          readString(pick(airport, ['name', 'Name'])) ??
          readString(pick(detail, ['name', 'Name'])),
      city:
          readString(pick(airport, ['city', 'City'])) ??
          readString(pick(detail, ['city', 'City'])),
      country:
          readString(pick(airport, ['country', 'Country'])) ??
          readString(pick(detail, ['country', 'Country'])),
      latitude:
          readDouble(pick(airport, ['latitude', 'lat', 'Lat'])) ??
          readDouble(pick(payloadRoot, ['lat', 'latitude', 'Lat'])),
      longitude:
          readDouble(pick(airport, ['longitude', 'lon', 'lng', 'Lon'])) ??
          readDouble(pick(payloadRoot, ['lng', 'lon', 'longitude', 'Lon'])),
      elevationFt:
          readInt(pick(airport, ['elevation', 'Elevation'])) ??
          readInt(pick(payloadRoot, ['elevation', 'Elevation'])),
      source:
          readString(
            pick(payloadRoot, ['database_source', 'source', 'Source']),
          ) ??
          readString(pick(airport, ['source', 'Source'])) ??
          readString(pick(detail, ['data_source', 'source', 'Source'])),
      airac:
          readString(pick(payloadRoot, ['airac', 'AIRAC'])) ??
          readString(pick(detail, ['airac', 'AIRAC'])),
      runways: runways,
      parkings: parkings,
      frequencies: frequencies,
    );
  }
}
