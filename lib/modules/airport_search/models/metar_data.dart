import 'model_utils.dart';

/// 气象报告 (METAR) 数据模型
class MetarData {
  /// 原始 METAR 文本
  final String? raw;

  /// 已解码/翻译的可读文本
  final String? decoded;

  /// 风向风速信息
  final String? wind;

  /// 能见度信息
  final String? visibility;

  /// 温度/露点信息
  final String? temperature;

  /// 气压计/修正海压信息 (Altimeter)
  final String? altimeter;

  const MetarData({
    this.raw,
    this.decoded,
    this.wind,
    this.visibility,
    this.temperature,
    this.altimeter,
  });

  /// 从 API 响应中构建 METAR 数据对象
  factory MetarData.fromApi(Map<String, dynamic> data) {
    final payloadRoot = asMap(pick(data, ['data'])) ?? data;
    return MetarData(
      raw: readString(pick(payloadRoot, ['raw_metar', 'raw', 'Raw', 'metar'])),
      decoded: readString(
        pick(payloadRoot, [
          'translated_metar',
          'decoded',
          'Decoded',
          'translatedMetar',
        ]),
      ),
      wind: readString(pick(payloadRoot, ['display_wind', 'wind'])),
      visibility: readString(
        pick(payloadRoot, ['display_visibility', 'visibility']),
      ),
      temperature: readString(
        pick(payloadRoot, ['display_temperature', 'temperature']),
      ),
      altimeter: readString(
        pick(payloadRoot, ['display_altimeter', 'altimeter']),
      ),
    );
  }
}
