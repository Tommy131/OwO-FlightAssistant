import { usePlannedRouteStore } from '../../common/providers/planned-route-store';
import { create } from 'zustand';
import {
  mergeById,
  pullRecords,
  pushRecord,
  removeRecord,
} from '../../../core/services/backend-sync';
import { PersistenceService } from '../../../core/services/persistence-service';
import { AppLogger } from '../../../core/utils/logger';
import { toJsonMap, type JsonMap } from '../../../core/utils/parse-utils';
import {
  airportDetailFromApi,
  metarFromApi,
} from '../../airport_search/models/airport-search-models';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import {
  briefingRecordFromJson,
  briefingRecordToJson,
  type BriefingAirportBundle,
  type BriefingRecord,
} from '../models/briefing-models';
import {
  buildBriefingSummary,
  buildFuelPlan,
  computeLegDistanceNm,
  generateFlightNumber,
  selectBestRunway,
} from '../services/briefing-service';

/**
 * 简报状态管理
 *
 * 对应 Flutter 版 `modules/briefing/providers/briefing_provider.dart`。
 * 桌面版把简报存成数据目录下的 .txt 文件；Web 版存 IndexedDB，
 * 并提供单份导出为 .txt（与桌面版文件内容一致）。
 */

const MODULE_NAME = 'briefing';
const HISTORY_KEY = 'records';
/** 巡航高度默认值，与桌面版一致 */
const DEFAULT_CRUISE_ALTITUDE = 35000;
/** 估算航速（KT），用于把距离折算成飞行时间 */
const PLANNING_SPEED_KT = 450;

export interface GenerateBriefingInput {
  departure: string;
  arrival: string;
  alternate?: string;
  flightNumber?: string;
  route?: string;
  cruiseAltitude?: number;
  departureRunway?: string;
  arrivalRunway?: string;
  alternateRunway?: string;
}

interface BriefingState {
  isLoading: boolean;
  latest: BriefingRecord | null;
  history: BriefingRecord[];
  errorMessage: string | null;

  init: () => Promise<void>;
  generateBriefing: (input: GenerateBriefingInput) => Promise<boolean>;
  selectRecord: (record: BriefingRecord | null) => void;
  deleteRecord: (createdAt: Date) => Promise<void>;
  /** 导出为纯文本（与桌面版落盘内容一致） */
  exportRecord: (record: BriefingRecord) => void;
  /** 导出为 JSON（可被本应用重新导入） */
  exportRecordJson: (record: BriefingRecord) => void;
  /** 导入 .json 或 .txt，返回导入条数 */
  importRecords: (file: File) => Promise<number>;
  clearHistory: () => Promise<void>;
}

export const useBriefingStore = create<BriefingState>((set, get) => ({
  isLoading: false,
  latest: null,
  history: [],
  errorMessage: null,

  async init() {
    try {
      await PersistenceService.ensureReady();
      const stored = PersistenceService.getModuleData<unknown[]>(MODULE_NAME, HISTORY_KEY);
      const localHistory = Array.isArray(stored)
        ? stored
            .map((item) => toJsonMap(item))
            .filter((item): item is JsonMap => item !== null)
            .map(briefingRecordFromJson)
        : [];

      // 后端是共享真相源；不可达时退回本地缓存
      const remoteRaw = await pullRecords('briefing');
      const history =
        remoteRaw === null
          ? localHistory
          : mergeById(
              remoteRaw.map(briefingRecordFromJson).map(withRecordId),
              localHistory.map(withRecordId),
            ).map(stripRecordId);
      history.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

      set({ history, latest: history[0] ?? null });
      await persistHistory(history);

      // 补传离线期间新增的简报
      if (remoteRaw !== null) {
        const remoteIds = new Set(
          remoteRaw.map((item) => briefingRecordId(briefingRecordFromJson(item))),
        );
        for (const record of history) {
          const id = briefingRecordId(record);
          if (remoteIds.has(id)) continue;
          await pushRecord('briefing', id, briefingRecordToJson(record));
        }
      }
    } catch (e) {
      AppLogger.warning(`[Briefing] load history failed: ${String(e)}`);
    }
  },

  async generateBriefing(input) {
    set({ isLoading: true, errorMessage: null });

    const generatedAt = new Date();
    const normalizedDeparture = input.departure.trim().toUpperCase();
    const normalizedArrival = input.arrival.trim().toUpperCase();
    const normalizedAlternate = input.alternate?.trim().toUpperCase() ?? '';
    const routeText =
      input.route && input.route.trim().length > 0 ? input.route.trim().toUpperCase() : 'DCT';
    const cruise = input.cruiseAltitude ?? DEFAULT_CRUISE_ALTITUDE;
    const flightNo =
      input.flightNumber && input.flightNumber.trim().length > 0
        ? input.flightNumber.trim().toUpperCase()
        : generateFlightNumber();

    try {
      // 1. 拉取起降与备降机场的详情 + METAR
      const [depBundle, arrBundle, altBundle] = await Promise.all([
        fetchAirportBundle(normalizedDeparture),
        fetchAirportBundle(normalizedArrival),
        normalizedAlternate.length === 0
          ? Promise.resolve(undefined)
          : fetchAirportBundle(normalizedAlternate),
      ]);

      // 2. 算路
      const distanceNm = computeLegDistanceNm(
        depBundle.airport.latitude,
        depBundle.airport.longitude,
        arrBundle.airport.latitude,
        arrBundle.airport.longitude,
      );
      const estimatedMinutes =
        distanceNm !== undefined ? Math.round((distanceNm / PLANNING_SPEED_KT) * 60) : undefined;

      // 3. 燃油计划
      // 有导入的 SimBrief 配载就用真实值，否则退回粗估
      const fuel = buildFuelPlan({
        distanceNm,
        hasAlternate: altBundle !== undefined,
        imported: usePlannedRouteStore.getState().plan?.fuel,
        importedEnrouteSeconds: usePlannedRouteStore.getState().plan?.enrouteSeconds,
      });

      // 4. 跑道：手填优先，否则按风向自动挑
      const depRunway = pickRunway(input.departureRunway, depBundle);
      const arrRunway = pickRunway(input.arrivalRunway, arrBundle);
      const altRunway = altBundle ? pickRunway(input.alternateRunway, altBundle) : undefined;

      // 5. 生成正文
      const content = buildBriefingSummary({
        generatedAt,
        flightNo,
        departure: depBundle,
        arrival: arrBundle,
        alternate: altBundle,
        route: routeText,
        cruiseAltitude: cruise,
        distanceNm,
        estimatedMinutes,
        depRunway,
        arrRunway,
        altRunway,
        fuel,
      });

      const record: BriefingRecord = {
        title: `${flightNo} ${normalizedDeparture}-${normalizedArrival}`,
        content,
        createdAt: generatedAt,
      };

      const history = [record, ...get().history];
      set({ latest: record, history, isLoading: false });
      await persistHistory(history);
      await pushRecord('briefing', briefingRecordId(record), briefingRecordToJson(record));
      return true;
    } catch (e) {
      AppLogger.error('[Briefing] generate failed', e);
      set({ isLoading: false, errorMessage: String(e) });
      return false;
    }
  },

  selectRecord(record) {
    set({ latest: record });
  },

  async deleteRecord(createdAt) {
    const removed = get().history.find(
      (record) => record.createdAt.getTime() === createdAt.getTime(),
    );
    const history = get().history.filter(
      (record) => record.createdAt.getTime() !== createdAt.getTime(),
    );
    set({
      history,
      latest:
        get().latest?.createdAt.getTime() === createdAt.getTime()
          ? (history[0] ?? null)
          : get().latest,
    });
    await persistHistory(history);
    if (removed) await removeRecord('briefing', briefingRecordId(removed));
  },

  exportRecord(record) {
    // 纯文本导出：与桌面版落盘的 .txt 内容完全一致
    downloadBlob(
      new Blob([record.content], { type: 'text/plain;charset=utf-8' }),
      `briefing_${sanitizeFileName(record.title)}.txt`,
    );
  },

  exportRecordJson(record) {
    // JSON 导出：带元数据，可被本应用重新导入
    downloadBlob(
      new Blob([JSON.stringify(briefingRecordToJson(record), null, 2)], {
        type: 'application/json',
      }),
      `briefing_${sanitizeFileName(record.title)}.json`,
    );
  },

  async importRecords(file) {
    const text = await file.text();
    const imported: BriefingRecord[] = [];

    if (file.name.toLowerCase().endsWith('.json')) {
      const decoded: unknown = JSON.parse(text);
      const rawList = Array.isArray(decoded) ? decoded : [decoded];
      for (const item of rawList) {
        const map = toJsonMap(item);
        if (!map) continue;
        const record = briefingRecordFromJson(map);
        if (record.content.trim().length === 0) continue;
        imported.push(record);
      }
    } else {
      // 纯文本：整份当作一条简报，标题从 FLT 行推断
      const content = text.trim();
      if (content.length === 0) return 0;
      const flightNo = content.match(/^FLT:\s*(\S+)/m)?.[1] ?? '';
      const route = content.match(/^DEP:\s*(\S+)/m)?.[1] ?? '';
      const arrival = content.match(/^ARR:\s*(\S+)/m)?.[1] ?? '';
      imported.push({
        title: [flightNo, route && arrival ? `${route}-${arrival}` : '']
          .filter((part) => part.length > 0)
          .join(' ')
          || file.name.replace(/\.[^.]+$/, ''),
        content,
        createdAt: new Date(),
      });
    }

    if (imported.length === 0) return 0;

    const byId = new Map(get().history.map((record) => [briefingRecordId(record), record]));
    for (const record of imported) byId.set(briefingRecordId(record), record);
    const history = [...byId.values()].sort(
      (a, b) => b.createdAt.getTime() - a.createdAt.getTime(),
    );

    set({ history, latest: imported[0] });
    await persistHistory(history);
    for (const record of imported) {
      await pushRecord('briefing', briefingRecordId(record), briefingRecordToJson(record));
    }
    return imported.length;
  },

  async clearHistory() {
    const previous = get().history;
    set({ history: [], latest: null });
    await persistHistory([]);
    for (const record of previous) {
      await removeRecord('briefing', briefingRecordId(record));
    }
  },
}));

// ──────────────────────────────────────────────────────────────────────────
// 内部
// ──────────────────────────────────────────────────────────────────────────

/** 拉取机场详情与 METAR；METAR 失败不影响简报生成（与桌面版回退一致） */
async function fetchAirportBundle(icao: string): Promise<BriefingAirportBundle> {
  await MiddlewareHttpService.init();
  const airportResponse = await MiddlewareHttpService.getAirportByIcao(icao);
  const airportBody = airportResponse.objectBody;
  if (!airportBody) throw new Error(`invalid airport response for ${icao}`);

  let metar: BriefingAirportBundle['metar'];
  try {
    const metarResponse = await MiddlewareHttpService.getMetarByIcao(icao);
    const metarBody = metarResponse.objectBody;
    if (metarBody) metar = metarFromApi(metarBody);
  } catch (e) {
    AppLogger.warning(`Failed to fetch METAR for ${icao}, falling back to static data: ${String(e)}`);
  }

  return { airport: airportDetailFromApi(airportBody), metar };
}

function pickRunway(manual: string | undefined, bundle: BriefingAirportBundle): string | undefined {
  if (manual && manual.trim().length > 0) return manual.trim().toUpperCase();
  return selectBestRunway(bundle.airport, bundle.metar);
}

async function persistHistory(history: BriefingRecord[]): Promise<void> {
  await PersistenceService.setModuleData(
    MODULE_NAME,
    HISTORY_KEY,
    history.map(briefingRecordToJson),
  );
}

/**
 * 简报的稳定 ID
 *
 * 简报模型本身没有 id 字段，用创建时间的毫秒数作为标识 ——
 * 纯数字，正好满足后端 `^[A-Za-z0-9_-]{1,128}$` 的校验。
 */
export function briefingRecordId(record: BriefingRecord): string {
  return String(record.createdAt.getTime());
}

/** 为 mergeById 临时补上 id 字段 */
function withRecordId(record: BriefingRecord): BriefingRecord & { id: string } {
  return { ...record, id: briefingRecordId(record) };
}

function stripRecordId(record: BriefingRecord & { id: string }): BriefingRecord {
  const { id: _id, ...rest } = record;
  return rest;
}

function sanitizeFileName(text: string): string {
  return text.replace(/[^\w-]+/g, '_').replace(/^_+|_+$/g, '') || 'record';
}

function downloadBlob(blob: Blob, fileName: string): void {
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  URL.revokeObjectURL(url);
}
