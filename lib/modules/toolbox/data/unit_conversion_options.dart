import '../localization/toolbox_localization_keys.dart';
import '../models/toolbox_models.dart';

/// 单位转换配置项数据
///
/// 用于定义气压、高度、重量、速度、距离及温度等航空常用的单位换算公式。
const List<UnitConversionOption> unitConversionOptions = [
  UnitConversionOption(
    labelKey: ToolboxLocalizationKeys.unitHpaToInhg,
    resultUnit: 'inHg',
    converter: _hpaToInhg,
  ),
  UnitConversionOption(
    labelKey: ToolboxLocalizationKeys.unitInhgToHpa,
    resultUnit: 'hPa',
    converter: _inhgToHpa,
  ),
  UnitConversionOption(
    labelKey: ToolboxLocalizationKeys.unitFtToM,
    resultUnit: 'm',
    converter: _ftToM,
  ),
  UnitConversionOption(
    labelKey: ToolboxLocalizationKeys.unitMToFt,
    resultUnit: 'ft',
    converter: _mToFt,
  ),
  UnitConversionOption(
    labelKey: ToolboxLocalizationKeys.unitLbToKg,
    resultUnit: 'kg',
    converter: _lbToKg,
  ),
  UnitConversionOption(
    labelKey: ToolboxLocalizationKeys.unitKgToLb,
    resultUnit: 'lb',
    converter: _kgToLb,
  ),
  UnitConversionOption(
    labelKey: ToolboxLocalizationKeys.unitKtToKmh,
    resultUnit: 'km/h',
    converter: _ktToKmh,
  ),
  UnitConversionOption(
    labelKey: ToolboxLocalizationKeys.unitKmhToKt,
    resultUnit: 'kt',
    converter: _kmhToKt,
  ),
  UnitConversionOption(
    labelKey: ToolboxLocalizationKeys.unitNmToKm,
    resultUnit: 'km',
    converter: _nmToKm,
  ),
  UnitConversionOption(
    labelKey: ToolboxLocalizationKeys.unitKmToNm,
    resultUnit: 'NM',
    converter: _kmToNm,
  ),
  UnitConversionOption(
    labelKey: ToolboxLocalizationKeys.unitCelsiusToFahrenheit,
    resultUnit: '°F',
    converter: _celsiusToFahrenheit,
  ),
  UnitConversionOption(
    labelKey: ToolboxLocalizationKeys.unitFahrenheitToCelsius,
    resultUnit: '°C',
    converter: _fahrenheitToCelsius,
  ),
];

double _hpaToInhg(double value) => value * 0.02953;
double _inhgToHpa(double value) => value / 0.02953;
double _ftToM(double value) => value * 0.3048;
double _mToFt(double value) => value / 0.3048;
double _lbToKg(double value) => value * 0.45359;
double _kgToLb(double value) => value / 0.45359;
double _ktToKmh(double value) => value * 1.852;
double _kmhToKt(double value) => value / 1.852;
double _nmToKm(double value) => value * 1.852;
double _kmToNm(double value) => value / 1.852;
double _celsiusToFahrenheit(double value) => (value * 9 / 5) + 32;
double _fahrenheitToCelsius(double value) => (value - 32) * 5 / 9;
