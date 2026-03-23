import 'airport_detail_data.dart';
import 'metar_data.dart';

/// 机场查询的完整结果合集
/// 同时包含机场的物理信息 (AirportDetailData) 和实时的气象信息 (MetarData)
class AirportQueryResult {
  /// 机场详细信息
  final AirportDetailData airport;

  /// 对应的气象报告信息
  final MetarData metar;

  const AirportQueryResult({required this.airport, required this.metar});
}
