import { useEffect, useState } from 'react';
import { AppLogger } from '../../../core/utils/logger';
import {
  airportDetailFromApi,
  type AirportDetailData,
} from '../../airport_search/models/airport-search-models';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';

/**
 * 简报机场解析
 *
 * 输入框里敲进去的四位码在生成简报之前就要落实到一个**真实机场**上：
 * 名字要能显示出来给人核对，跑道要能从后端取回来供人选择 ——
 * 而不是让人凭记忆手打跑道号，打错了也没人拦。
 *
 * 解析结果按 ICAO 缓存在模块级 Map 里：起飞/落地/备降三个输入框
 * 经常填同一个机场，没必要重复打接口。
 */

/** ICAO：4 位字母数字 */
export const ICAO_PATTERN = /^[A-Z0-9]{4}$/;

export type AirportResolutionStatus =
  | 'idle' // 还没填够 4 位
  | 'loading'
  | 'found'
  | 'notFound' // 格式对但库里查不到
  | 'error'; // 后端不可达

export interface AirportResolution {
  readonly status: AirportResolutionStatus;
  readonly airport?: AirportDetailData;
}

const IDLE: AirportResolution = { status: 'idle' };

/** ICAO → 解析结果；notFound 也缓存，避免对着不存在的码反复打接口 */
const cache = new Map<string, AirportResolution>();

/** 输入停顿多久后才去查（毫秒） */
const DEBOUNCE_MS = 350;

export function useAirportResolution(icao: string): AirportResolution {
  const code = icao.trim().toUpperCase();
  const valid = ICAO_PATTERN.test(code);

  const [resolution, setResolution] = useState<AirportResolution>(() =>
    valid ? (cache.get(code) ?? IDLE) : IDLE,
  );

  useEffect(() => {
    if (!valid) {
      setResolution(IDLE);
      return;
    }

    const cached = cache.get(code);
    if (cached) {
      setResolution(cached);
      return;
    }

    let cancelled = false;
    setResolution({ status: 'loading' });

    const timer = setTimeout(() => {
      void (async () => {
        const result = await resolveAirport(code);
        // 结果无论如何都进缓存，即便本次已被取消
        cache.set(code, result);
        if (!cancelled) setResolution(result);
      })();
    }, DEBOUNCE_MS);

    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [code, valid]);

  return resolution;
}

async function resolveAirport(icao: string): Promise<AirportResolution> {
  try {
    await MiddlewareHttpService.init();
    const response = await MiddlewareHttpService.getAirportByIcao(icao);
    const body = response.objectBody;
    if (!body) return { status: 'notFound' };

    const airport = airportDetailFromApi(body);
    // 解析器在字段缺失时会把 icao 兜底成空串，这种也算没查到
    if (!airport.icao) return { status: 'notFound' };
    return { status: 'found', airport };
  } catch (e) {
    // 「查无此机场」和「后端连不上」要分开报，否则用户会以为是自己码打错了
    const message = String(e);
    if (/404|not_found|notFound/i.test(message)) return { status: 'notFound' };
    AppLogger.warning(`[Briefing] resolve ${icao} failed: ${message}`);
    return { status: 'error' };
  }
}

/** 跑道方向选项（单个跑道端） */
export interface RunwayEndOption {
  /** 跑道端编号，如 `18L` */
  readonly ident: string;
  /** 供下拉展示的补充信息，如 `3800m · ASPH` */
  readonly detail?: string;
}

/**
 * 把机场跑道拆成可供选择的**跑道端**
 *
 * 后端给的 ident 是一条跑道的两端合写（`18L/36R`），
 * 但起降只会用其中一端，所以这里拆开列出。
 */
export function runwayEndOptions(airport: AirportDetailData | undefined): RunwayEndOption[] {
  if (!airport) return [];

  const seen = new Set<string>();
  const options: RunwayEndOption[] = [];

  for (const runway of airport.runways) {
    const detail = [
      runway.lengthM !== undefined ? `${Math.round(runway.lengthM)}m` : null,
      runway.surface,
    ]
      .filter((part): part is string => typeof part === 'string' && part.length > 0)
      .join(' · ');

    // 优先用明确的两端字段，缺失时再从合写的 ident 里拆
    const ends =
      runway.leIdent || runway.heIdent
        ? [runway.leIdent, runway.heIdent]
        : runway.ident.split('/');

    for (const raw of ends) {
      const ident = (raw ?? '').trim().toUpperCase();
      if (ident.length === 0 || ident === '-' || seen.has(ident)) continue;
      seen.add(ident);
      options.push({ ident, detail: detail.length > 0 ? detail : undefined });
    }
  }

  // 按跑道号排序，让下拉里的顺序符合直觉
  options.sort((a, b) => a.ident.localeCompare(b.ident, undefined, { numeric: true }));
  return options;
}
