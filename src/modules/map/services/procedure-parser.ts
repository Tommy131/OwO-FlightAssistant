/**
 * 公布程序解析（纯函数）
 *
 * 中间件已经把 CIFP 归一化过（含定位点坐标解析、FL 高度换算），
 * 这里只做「后端字段 → 前端模型」的翻译与校验。
 *
 * 有一条必须保住：**`has_position` 为假的航段不能丢**。
 * `CA`（飞到某高度）这类以条件结束的航段本就没有定位点，
 * 丢掉它整条程序的序号就断了，而起飞后的第一段往往正是 CA。
 */

import { pickDouble, toJsonMap, toText } from '../../../core/utils/parse-utils';
import { isValidCoordinate } from '../../../core/utils/coordinates';
import type {
  MapProcedure,
  MapProcedureKind,
  MapProcedureLeg,
} from '../models/map-models';

const PROCEDURE_KINDS: readonly string[] = ['SID', 'STAR', 'APPROACH'];

/** 解析一段航段 */
function parseProcedureLeg(raw: unknown): MapProcedureLeg | null {
  const map = toJsonMap(raw);
  if (!map) return null;

  const fixIdent = toText(map.fix_ident).trim();
  const latitude = pickDouble(map, ['lat']);
  const longitude = pickDouble(map, ['lon']);

  // 后端已经判过能不能解析出坐标；这里再校验一次范围，
  // 免得上游数据异常时把航段画到 (0,0)
  const hasPosition =
    map.has_position === true &&
    latitude !== undefined &&
    longitude !== undefined &&
    isValidCoordinate(latitude, longitude);

  const legType = toText(map.leg_type).trim();
  const turnDirection = toText(map.turn_direction).trim();
  const altitudeDescription = toText(map.altitude_description).trim();

  return {
    sequence: pickDouble(map, ['sequence']) ?? 0,
    fixIdent: fixIdent.length > 0 ? fixIdent : undefined,
    position: hasPosition ? { latitude, longitude } : undefined,
    hasPosition,
    legType: legType.length > 0 ? legType : undefined,
    turnDirection: turnDirection.length > 0 ? turnDirection : undefined,
    altitudeDescription: altitudeDescription.length > 0 ? altitudeDescription : undefined,
    altitude1Ft: pickDouble(map, ['altitude1_ft']),
    altitude2Ft: pickDouble(map, ['altitude2_ft']),
    speedLimitKt: pickDouble(map, ['speed_limit_kt']),
    magneticCourse: pickDouble(map, ['magnetic_course']),
  };
}

/**
 * 解析一条程序。
 *
 * 至少要有**两个带坐标的航段**才留下 —— 一个点画不出线，
 * 留着只会在程序列表里占位。
 */
export function parseProcedure(raw: unknown): MapProcedure | null {
  const map = toJsonMap(raw);
  if (!map) return null;

  const kind = toText(map.kind).trim().toUpperCase();
  if (!PROCEDURE_KINDS.includes(kind)) return null;

  const name = toText(map.name).trim();
  if (name.length === 0) return null;

  const rawLegs = Array.isArray(map.legs) ? map.legs : [];
  const legs = rawLegs
    .map(parseProcedureLeg)
    .filter((leg): leg is MapProcedureLeg => leg !== null);

  if (legs.filter((leg) => leg.hasPosition).length < 2) return null;

  const transition = toText(map.transition).trim();
  return {
    kind: kind as MapProcedureKind,
    name,
    transition: transition.length > 0 ? transition : undefined,
    legs,
  };
}

/** 解析接口返回的整份程序列表 */
export function parseProcedureList(raw: unknown): MapProcedure[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .map(parseProcedure)
    .filter((procedure): procedure is MapProcedure => procedure !== null);
}

/**
 * 把高度限制格式化成航图上的写法。
 *
 * `+2960` → `2960+`（不低于）、`-5000` → `5000-`（不高于）、
 * `B17700/16700` → `17700/16700`（区间）。
 * 描述符缺失时只给数字。
 */
export function formatAltitudeConstraint(leg: MapProcedureLeg): string | undefined {
  const first = leg.altitude1Ft;
  if (first === undefined || first <= 0) return undefined;
  const rounded = Math.round(first);

  switch (leg.altitudeDescription) {
    case '+':
      return `${rounded}+`;
    case '-':
      return `${rounded}-`;
    case 'B': {
      const second = leg.altitude2Ft;
      return second !== undefined && second > 0
        ? `${rounded}/${Math.round(second)}`
        : `${rounded}`;
    }
    default:
      return `${rounded}`;
  }
}
