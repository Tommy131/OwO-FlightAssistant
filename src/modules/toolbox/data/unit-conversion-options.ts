import { ToolboxLocalizationKeys as K } from '../localization/toolbox-localization';
import type { UnitConversionOption } from '../models/toolbox-models';

/**
 * 单位转换配置项
 *
 * 对应 Flutter 版 `modules/toolbox/data/unit_conversion_options.dart`。
 * 气压、高度、重量、速度、距离、温度共 12 个换算方向，系数逐个对齐。
 */
export const unitConversionOptions: UnitConversionOption[] = [
  { labelKey: K.unitHpaToInhg, resultUnit: 'inHg', converter: (v) => v * 0.02953 },
  { labelKey: K.unitInhgToHpa, resultUnit: 'hPa', converter: (v) => v / 0.02953 },
  { labelKey: K.unitFtToM, resultUnit: 'm', converter: (v) => v * 0.3048 },
  { labelKey: K.unitMToFt, resultUnit: 'ft', converter: (v) => v / 0.3048 },
  { labelKey: K.unitLbToKg, resultUnit: 'kg', converter: (v) => v * 0.45359 },
  { labelKey: K.unitKgToLb, resultUnit: 'lb', converter: (v) => v / 0.45359 },
  { labelKey: K.unitKtToKmh, resultUnit: 'km/h', converter: (v) => v * 1.852 },
  { labelKey: K.unitKmhToKt, resultUnit: 'kt', converter: (v) => v / 1.852 },
  { labelKey: K.unitNmToKm, resultUnit: 'km', converter: (v) => v * 1.852 },
  { labelKey: K.unitKmToNm, resultUnit: 'NM', converter: (v) => v / 1.852 },
  {
    labelKey: K.unitCelsiusToFahrenheit,
    resultUnit: '°F',
    converter: (v) => (v * 9) / 5 + 32,
  },
  {
    labelKey: K.unitFahrenheitToCelsius,
    resultUnit: '°C',
    converter: (v) => ((v - 32) * 5) / 9,
  },
];
