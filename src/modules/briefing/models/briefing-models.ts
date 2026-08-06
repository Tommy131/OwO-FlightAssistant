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
export interface BriefingFuelPlan {
  trip: number;
  alternate: number;
  reserve: number;
  taxi: number;
  extra: number;
  total: number;
  avgFlow: number;
  estimatedArrivalFuel: number;
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
