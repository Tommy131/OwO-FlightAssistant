/**
 * 工具箱数据模型
 * 对应 Flutter 版 `modules/toolbox/models/toolbox_models.dart`
 */

/** 单位转换配置项 */
export interface UnitConversionOption {
  /** 国际化显示的标签 key */
  readonly labelKey: string;
  /** 转换结果的单位后缀（如 'hPa' / 'inHg'） */
  readonly resultUnit: string;
  /** 具体的转换计算函数 */
  readonly converter: (value: number) => number;
}

/** 航空术语 */
export interface AviationTerm {
  /** 术语缩写（如 'V1' / 'ILS'） */
  readonly abbreviation: string;
  /** 英文全称 */
  readonly fullName: string;
  /** 中文译名 */
  readonly chineseName: string;
  /** 详细解释 */
  readonly description?: string;
}

/** 用于搜索展示的复合字符串 */
export function termDisplayValue(term: AviationTerm): string {
  return `${term.chineseName} (${term.fullName})`;
}

/** 工具箱分区（对应 AppBar 侧边二级菜单的 6 个入口） */
export type ToolboxSection =
  | 'unitConversion'
  | 'termTranslation'
  | 'flightCalculators'
  | 'weatherDecode'
  | 'performanceTools'
  | 'opsTools';

export const TOOLBOX_SECTIONS: ToolboxSection[] = [
  'unitConversion',
  'termTranslation',
  'flightCalculators',
  'weatherDecode',
  'performanceTools',
  'opsTools',
];
