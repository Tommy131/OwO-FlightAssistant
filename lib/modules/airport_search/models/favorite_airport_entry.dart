import 'model_utils.dart';
import 'airport_detail_data.dart';

/// 收藏机场的条目数据模型
/// 专门用于在本地存储中保存用户收藏的机场简要信息
class FavoriteAirportEntry {
  /// 收藏机场的 ICAO 代码
  final String icao;

  /// 收藏时的机场名称
  final String? name;

  /// 收藏时的机场经纬度坐标
  final double? latitude;
  final double? longitude;

  const FavoriteAirportEntry({
    required this.icao,
    this.name,
    this.latitude,
    this.longitude,
  });

  /// 从完整的机场详情模型中抽取关键信息构建收藏项
  factory FavoriteAirportEntry.fromAirport(AirportDetailData airport) {
    return FavoriteAirportEntry(
      icao: airport.icao.toUpperCase(),
      name: airport.name,
      latitude: airport.latitude,
      longitude: airport.longitude,
    );
  }

  /// 转换为 JSON 格式，以便持久化存储
  Map<String, dynamic> toJson() {
    return {
      'icao': icao,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// 从 JSON 数据中加载收藏条目
  factory FavoriteAirportEntry.fromJson(Map<String, dynamic> json) {
    return FavoriteAirportEntry(
      icao: (readString(json['icao']) ?? '').toUpperCase(),
      name: readString(json['name']),
      latitude: readDouble(json['latitude']),
      longitude: readDouble(json['longitude']),
    );
  }
}
