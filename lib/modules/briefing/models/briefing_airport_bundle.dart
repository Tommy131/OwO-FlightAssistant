import '../../airport_search/models/airport_search_models.dart';

/// 机场数据束模型
/// 用于打包一个机场的基础详情（静态）和 METAR 数据（动态）
class BriefingAirportBundle {
  final AirportDetailData airport;
  final MetarData? metar;

  const BriefingAirportBundle({required this.airport, this.metar});
}
