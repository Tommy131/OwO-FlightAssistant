import 'model_utils.dart';

/// 机场停机位信息模型
class AirportParkingData {
  /// 停机位名称 (例如: GATE 12)
  final String? name;

  /// 经纬度位置
  final double? latitude;
  final double? longitude;

  /// 停机位朝向角度 (Heading)
  final double? headingDeg;

  const AirportParkingData({
    this.name,
    this.latitude,
    this.longitude,
    this.headingDeg,
  });

  /// 从 API 响应数据中构建停机位对象
  factory AirportParkingData.fromApi(Map<String, dynamic> data) {
    return AirportParkingData(
      name: readString(pick(data, ['name', 'Name', 'ident', 'Ident'])),
      latitude: readDouble(pick(data, ['lat', 'latitude', 'Lat'])),
      longitude: readDouble(pick(data, ['lon', 'lng', 'longitude', 'Lon'])),
      headingDeg: readDouble(
        pick(data, ['heading_deg', 'headingDeg', 'heading', 'Heading']),
      ),
    );
  }
}
