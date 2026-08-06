import type {
  AirportDetailData,
  MetarData,
} from '../../airport_search/models/airport-search-models';
import { toText, type JsonMap } from '../../../core/utils/parse-utils';

/**
 * 简报数据模型
 * 对应 Flutter 版 `modules/briefing/models/*.dart`
 */

/** 单个机场的打包数据（详情 + 气象） */
export interface BriefingAirportBundle {
  airport: AirportDetailData;
  metar?: MetarData;
}

/** 燃油计划（单位 KG，avgFlow 为 KG/H） */
/**
 * 燃油数据的来源
 *
 * `simbrief` 是导入的真实配载，`estimate` 是本地按距离粗估的。
 * 两者精度差着数量级，简报正文必须标明，否则用户没法判断能不能照着加油。
 */
export type BriefingFuelSource = 'simbrief' | 'estimate';

export interface BriefingFuelPlan {
  trip: number;
  alternate: number;
  reserve: number;
  taxi: number;
  extra: number;
  total: number;
  avgFlow: number;
  estimatedArrivalFuel: number;
  /**
   * 油量单位，直接沿用来源的单位、**不做换算**。
   *
   * SimBrief 给的是用户自己设置的单位（kg 或 lbs），那是他机上 FMS 用的那套；
   * 换算过去反而对不上，还会引入精度损失。本地估算沿用桌面版的 KG。
   */
  units: string;
  source: BriefingFuelSource;
}

/** 一份已生成的简报记录 */
export interface BriefingRecord {
  title: string;
  content: string;
  createdAt: Date;
}

export function briefingRecordToJson(record: BriefingRecord): JsonMap {
  return {
    title: record.title,
    content: record.content,
    createdAt: record.createdAt.toISOString(),
  };
}

export function briefingRecordFromJson(json: JsonMap): BriefingRecord {
  return {
    title: typeof json.title === 'string' ? json.title : '',
    content: typeof json.content === 'string' ? json.content : '',
    createdAt: json.createdAt ? new Date(toText(json.createdAt)) : new Date(),
  };
}
