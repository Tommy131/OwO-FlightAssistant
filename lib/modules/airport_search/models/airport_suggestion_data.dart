import 'model_utils.dart';

/// 机场搜索建议的数据模型
/// 用于搜索框输入时的自动联想建议
class AirportSuggestionData {
  /// 机场 ICAO 代码
  final String icao;

  /// 机场名称 (中英文)
  final String? name;

  /// 数据来源 (例如: Navigraph, SimBrief)
  final String? source;

  const AirportSuggestionData({required this.icao, this.name, this.source});

  /// 从 API 响应数据中构建搜索建议项
  factory AirportSuggestionData.fromApi(Map<String, dynamic> data) {
    final icao = readString(pick(data, ['icao', 'ICAO']))?.toUpperCase() ?? '';
    return AirportSuggestionData(
      icao: icao,
      name: readString(pick(data, ['name', 'Name'])),
      source: readString(pick(data, ['source', 'Source'])),
    );
  }
}
