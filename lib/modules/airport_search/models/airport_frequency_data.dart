import 'model_utils.dart';

/// 机场通讯频率信息模型
class AirportFrequencyData {
  /// 通讯类型 (例如: Tower, Ground, ATIS)
  final String? type;

  /// 频率值 (例如: 118.10)
  final String? value;

  const AirportFrequencyData({this.type, this.value});

  /// 从 API 响应数据中构建频率对象
  factory AirportFrequencyData.fromApi(Map<String, dynamic> data) {
    return AirportFrequencyData(
      type: readString(pick(data, ['type', 'Type'])),
      value: readString(pick(data, ['frequency', 'Frequency', 'value'])),
    );
  }
}
