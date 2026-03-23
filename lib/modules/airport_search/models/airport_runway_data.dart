import 'model_utils.dart';

/// 机场跑道的相关信息模型
class AirportRunwayData {
  /// 跑道标识 (例如: 12R/30L)
  final String ident;

  /// 跑道总长度 (以米为单位)
  final double? lengthM;

  /// 跑道路面材质类型
  final String? surface;

  /// 低端跑道标识 (Low End Ident)
  final String? leIdent;

  /// 高端跑道标识 (High End Ident)
  final String? heIdent;

  /// 低端跑道纬度
  final double? leLat;

  /// 低端跑道经度
  final double? leLon;

  /// 高端跑道纬度
  final double? heLat;

  /// 高端跑道经度
  final double? heLon;

  const AirportRunwayData({
    required this.ident,
    this.lengthM,
    this.surface,
    this.leIdent,
    this.heIdent,
    this.leLat,
    this.leLon,
    this.heLat,
    this.heLon,
  });

  /// 从 API 响应数据中构建跑道对象
  factory AirportRunwayData.fromApi(Map<String, dynamic> data) {
    return AirportRunwayData(
      ident: readString(pick(data, ['ident', 'Ident', 'name', 'Name'])) ?? '-',
      lengthM: readDouble(pick(data, ['length_m', 'lengthM', 'LengthM'])),
      surface: readString(pick(data, ['surface', 'Surface', 'type', 'Type'])),
      leIdent: readString(pick(data, ['le_ident', 'leIdent', 'LeIdent'])),
      heIdent: readString(pick(data, ['he_ident', 'heIdent', 'HeIdent'])),
      leLat: readDouble(pick(data, ['le_lat', 'leLat', 'LeLat'])),
      leLon: readDouble(pick(data, ['le_lon', 'leLon', 'LeLon'])),
      heLat: readDouble(pick(data, ['he_lat', 'heLat', 'HeLat'])),
      heLon: readDouble(pick(data, ['he_lon', 'heLon', 'HeLon'])),
    );
  }
}
