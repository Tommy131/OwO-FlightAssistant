import 'airport_detail_data.dart';

/// 机场简要信息模型 (用于列表和数据库)
class AirportInfo {
  final String icaoCode;
  final String iataCode;
  final String nameChinese;
  final double latitude;
  final double longitude;

  const AirportInfo({
    required this.icaoCode,
    this.iataCode = '',
    required this.nameChinese,
    required this.latitude,
    required this.longitude,
  });

  factory AirportInfo.placeholder(String icaoCode) {
    return AirportInfo(
      icaoCode: icaoCode.toUpperCase(),
      nameChinese: '未知机场 (在线获取)',
      latitude: 0.0,
      longitude: 0.0,
    );
  }

  factory AirportInfo.fromDetail(AirportDetailData detail) {
    return AirportInfo(
      icaoCode: detail.icaoCode,
      iataCode: detail.iataCode ?? '',
      nameChinese: detail.name,
      latitude: detail.latitude,
      longitude: detail.longitude,
    );
  }

  String get displayName {
    final codes = [icaoCode, if (iataCode.isNotEmpty) iataCode].join('/');
    return '$codes $nameChinese';
  }
}
