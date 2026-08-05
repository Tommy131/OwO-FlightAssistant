import { translate } from '../../../core/services/localization-service';
import { toJsonMap, type JsonMap } from '../../../core/utils/parse-utils';
import type { FlightData } from '../../common/models/common-models';
import { createA320Checklist } from '../data/a320-checklist';
import { createB737Checklist } from '../data/b737-checklist';
import { createGenericChecklist } from '../data/generic-checklist';
import { ChecklistLocalizationKeys } from '../localization/checklist-localization';
import {
  CHECKLIST_PHASES,
  type AircraftChecklist,
  type AircraftFamily,
  type ChecklistItem,
  type ChecklistPhase,
} from '../models/flight-checklist';

/**
 * 检查单相关服务
 *
 * 对应 Flutter 版 `modules/checklist/services/` 下的四个文件：
 *   - aircraft_resolver.dart   机型匹配
 *   - flight_phase_deriver.dart 飞行阶段推导
 *   - checklist_parser.dart     文件解析（json / txt / csv）
 *   - checklist_serializer.dart 导出序列化
 */

// ──────────────────────────────────────────────────────────────────────────
// 内建检查单
// ──────────────────────────────────────────────────────────────────────────

/** 返回全部内建预置检查单 */
export function getBuiltInChecklists(): AircraftChecklist[] {
  return [
    createGenericChecklist(translate(ChecklistLocalizationKeys.builtInGenericAircraft)),
    createA320Checklist('A320-200 / A321 / A319'),
    createB737Checklist('B737-800 / Max'),
  ];
}

// ──────────────────────────────────────────────────────────────────────────
// 机型匹配（AircraftResolver）
// ──────────────────────────────────────────────────────────────────────────

/**
 * 从机型列表中按标识符匹配最合适的检查单
 *
 * 匹配优先级：ID/名称精确包含 → 家族模糊识别 → 通用机型 → 列表首项
 */
export function resolveAircraft(
  identifier: string | undefined,
  aircraftList: AircraftChecklist[],
): AircraftChecklist | null {
  if (aircraftList.length === 0) return null;
  const normalized = (identifier ?? '').trim().toLowerCase();

  if (normalized.length === 0) {
    return findGeneric(aircraftList) ?? aircraftList[0];
  }

  // ID 或名称精确包含
  for (const aircraft of aircraftList) {
    const id = aircraft.id.toLowerCase();
    const name = aircraft.name.toLowerCase();
    if (normalized.includes(id) || normalized.includes(name)) return aircraft;
  }

  // 家族模糊匹配
  if (looksLikeB737(normalized)) {
    return findByFamily('b737', aircraftList) ?? findGeneric(aircraftList) ?? aircraftList[0];
  }
  if (looksLikeA320(normalized)) {
    return findByFamily('a320', aircraftList) ?? findGeneric(aircraftList) ?? aircraftList[0];
  }

  return findGeneric(aircraftList) ?? aircraftList[0];
}

/** 由种子字符串推断机型家族（导入时自动归类用） */
export function inferFamily(seed: string): AircraftFamily {
  const n = seed.toLowerCase();
  if (n.includes('737') || n.includes('b738')) return 'b737';
  if (n.includes('320') || n.includes('321') || n.includes('319') || n.includes('a32')) {
    return 'a320';
  }
  return 'generic';
}

function looksLikeA320(text: string): boolean {
  return (
    text.includes('a320') ||
    text.includes('a319') ||
    text.includes('a321') ||
    text.includes('a32n') ||
    text.includes('airbus a3')
  );
}

function looksLikeB737(text: string): boolean {
  return (
    text.includes('b737') ||
    text.includes('737') ||
    text.includes('b738') ||
    text.includes('zibo') ||
    text.includes('boeing 737')
  );
}

function findByFamily(
  family: AircraftFamily,
  list: AircraftChecklist[],
): AircraftChecklist | null {
  return list.find((aircraft) => aircraft.family === family) ?? null;
}

function findGeneric(list: AircraftChecklist[]): AircraftChecklist | null {
  return (
    list.find(
      (aircraft) => aircraft.family === 'generic' || aircraft.id.toLowerCase() === 'generic',
    ) ?? null
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 飞行阶段推导（FlightPhaseDeriver）
// ──────────────────────────────────────────────────────────────────────────

/**
 * 从实时飞行数据推导当前检查单阶段
 *
 * 优先级：后端明确返回的 flightPhase → 高度/垂速/地速/停机刹车推算
 */
export function derivePhase(flightData: FlightData): ChecklistPhase | null {
  const fromBackend = mapBackendPhase(flightData.flightPhase);
  if (fromBackend) return fromBackend;

  const onGround = flightData.onGround;
  if (onGround === undefined) return null;

  const groundSpeed = flightData.groundSpeed ?? 0;
  const altitude = flightData.altitude ?? 0;
  const verticalSpeed = flightData.verticalSpeed ?? 0;
  const parkingBrake = flightData.parkingBrake ?? false;
  const engineRunning =
    (flightData.engine1Running ?? false) || (flightData.engine2Running ?? false);

  if (!onGround) {
    // 空中：低空大下降率 → 进近前；高空大下降率 → 下降前；其余按巡航
    if (altitude <= 5000 && verticalSpeed <= -500) return 'beforeApproach';
    if (verticalSpeed <= -700 && altitude > 5000) return 'beforeDescent';
    return 'cruise';
  }

  // 地面：按地速从高到低区分
  if (groundSpeed >= 45) return 'afterLanding';
  if (groundSpeed >= 8) return 'beforeTaxi';
  if (!parkingBrake && engineRunning) return 'beforePushback';
  if (parkingBrake && engineRunning) return 'beforeTakeoff';
  if (parkingBrake && !engineRunning) return 'coldAndDark';

  return 'parking';
}

/**
 * 是否应自动切换到新阶段
 *
 * 规则：只允许阶段前进；落地后/停机/冷舱可以倒退（对应新一段航班循环）
 */
export function shouldApplyPhase(current: ChecklistPhase, next: ChecklistPhase): boolean {
  const currentIndex = CHECKLIST_PHASES.indexOf(current);
  const nextIndex = CHECKLIST_PHASES.indexOf(next);
  if (nextIndex >= currentIndex) return true;
  return next === 'afterLanding' || next === 'parking' || next === 'coldAndDark';
}

function mapBackendPhase(phase: string | undefined): ChecklistPhase | null {
  switch ((phase ?? '').trim().toLowerCase()) {
    case 'taxi':
      return 'beforeTaxi';
    case 'takeoff':
      return 'beforeTakeoff';
    case 'climb':
    case 'cruise':
      return 'cruise';
    case 'approach':
      return 'beforeApproach';
    case 'landing':
      return 'afterLanding';
    default:
      return null;
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 文件解析（ChecklistParser）
// ──────────────────────────────────────────────────────────────────────────

/**
 * 解析检查单文件内容，支持三种格式：
 *   - `.json` 完整结构（导出格式，可含多机型）
 *   - `.csv`  `phase,task,response[,detail]`
 *   - `.txt`  `[phase]` 分节 + `task | response` 行
 */
export function parseChecklistFile(fileName: string, content: string): AircraftChecklist[] {
  const extension = fileName.split('.').pop()?.toLowerCase() ?? '';
  const baseName = fileName.replace(/\.[^.]+$/, '');

  try {
    if (extension === 'json') return parseJson(content, baseName);
    if (extension === 'csv') return parseDelimited(content, baseName, 'csv');
    return parseDelimited(content, baseName, 'txt');
  } catch {
    return [];
  }
}

function parseJson(content: string, baseName: string): AircraftChecklist[] {
  const decoded: unknown = JSON.parse(content);
  const rawList = Array.isArray(decoded)
    ? decoded
    : Array.isArray((decoded as JsonMap)?.aircraft)
      ? ((decoded as JsonMap).aircraft as unknown[])
      : [decoded];

  const result: AircraftChecklist[] = [];
  for (const raw of rawList) {
    const map = toJsonMap(raw);
    if (!map) continue;

    const sectionsRaw = Array.isArray(map.sections) ? map.sections : [];
    const sections = sectionsRaw
      .map((item) => toJsonMap(item))
      .filter((item): item is JsonMap => item !== null)
      .map((sectionMap) => {
        const phase = normalizePhase(String(sectionMap.phase ?? ''));
        const itemsRaw = Array.isArray(sectionMap.items) ? sectionMap.items : [];
        const items: ChecklistItem[] = itemsRaw
          .map((item) => toJsonMap(item))
          .filter((item): item is JsonMap => item !== null)
          .map((itemMap, index) => ({
            id: String(itemMap.id ?? `${phase}_${index}`),
            task: String(itemMap.task ?? ''),
            response: String(itemMap.response ?? ''),
            detail: itemMap.detail ? String(itemMap.detail) : undefined,
            isChecked: false,
          }))
          .filter((item) => item.task.length > 0);
        return { phase, items };
      })
      .filter((section) => section.items.length > 0);

    if (sections.length === 0) continue;
    const name = String(map.name ?? baseName);
    result.push({
      id: String(map.id ?? slugify(name)),
      name,
      family: normalizeFamily(map.family, name),
      sections,
    });
  }
  return result;
}

/** 解析 csv / txt 两种纯文本格式，合并为单个机型 */
function parseDelimited(
  content: string,
  baseName: string,
  format: 'csv' | 'txt',
): AircraftChecklist[] {
  const byPhase = new Map<ChecklistPhase, ChecklistItem[]>();
  let currentPhase: ChecklistPhase = 'coldAndDark';
  let counter = 0;

  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line.length === 0 || line.startsWith('#') || line.startsWith('//')) continue;

    // txt 格式的分节标记：[before_taxi]
    const sectionMatch = line.match(/^\[(.+)\]$/);
    if (sectionMatch) {
      currentPhase = normalizePhase(sectionMatch[1]);
      continue;
    }

    const cells =
      format === 'csv'
        ? splitCsvLine(line)
        : line.split('|').map((cell) => cell.trim());

    // csv 首列是阶段；txt 直接是 task | response
    let phase = currentPhase;
    let task: string;
    let response: string;
    let detail: string | undefined;

    if (format === 'csv' && cells.length >= 3) {
      // 跳过表头
      if (cells[0].toLowerCase() === 'phase') continue;
      phase = normalizePhase(cells[0]);
      task = cells[1];
      response = cells[2];
      detail = cells[3];
    } else {
      task = cells[0] ?? '';
      response = cells[1] ?? '';
      detail = cells[2];
    }

    if (task.length === 0) continue;
    const items = byPhase.get(phase) ?? [];
    items.push({
      id: `imported_${counter++}`,
      task,
      response,
      detail: detail && detail.length > 0 ? detail : undefined,
      isChecked: false,
    });
    byPhase.set(phase, items);
  }

  if (byPhase.size === 0) return [];

  // 按标准飞行阶段顺序排列节段
  const sections = CHECKLIST_PHASES.filter((phase) => byPhase.has(phase)).map((phase) => ({
    phase,
    items: byPhase.get(phase) ?? [],
  }));

  return [
    {
      id: slugify(baseName),
      name: baseName,
      family: inferFamily(baseName),
      sections,
    },
  ];
}

/** 简易 CSV 行拆分，支持双引号包裹 */
function splitCsvLine(line: string): string[] {
  const cells: string[] = [];
  let current = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (inQuotes) {
      if (ch === '"' && line[i + 1] === '"') {
        current += '"';
        i++;
      } else if (ch === '"') {
        inQuotes = false;
      } else {
        current += ch;
      }
      continue;
    }
    if (ch === '"') inQuotes = true;
    else if (ch === ',') {
      cells.push(current.trim());
      current = '';
    } else current += ch;
  }
  cells.push(current.trim());
  return cells;
}

/** 把任意写法（snake_case / camelCase / 中文别名）归一为标准阶段 */
function normalizePhase(raw: string): ChecklistPhase {
  const normalized = raw.trim().toLowerCase().replace(/[\s_-]/g, '');
  for (const phase of CHECKLIST_PHASES) {
    if (phase.toLowerCase() === normalized) return phase;
  }
  const aliases: Record<string, ChecklistPhase> = {
    colddark: 'coldAndDark',
    cold: 'coldAndDark',
    pushback: 'beforePushback',
    taxi: 'beforeTaxi',
    takeoff: 'beforeTakeoff',
    climb: 'cruise',
    descent: 'beforeDescent',
    approach: 'beforeApproach',
    landing: 'afterLanding',
    shutdown: 'parking',
    parking: 'parking',
  };
  return aliases[normalized] ?? 'coldAndDark';
}

function normalizeFamily(raw: unknown, fallbackSeed: string): AircraftFamily {
  const value = String(raw ?? '').toLowerCase();
  if (value === 'a320' || value === 'b737' || value === 'generic') return value;
  return inferFamily(fallbackSeed);
}

function slugify(text: string): string {
  return (
    text
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '') || 'imported'
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 导出序列化（ChecklistSerializer）
// ──────────────────────────────────────────────────────────────────────────

/** 序列化为可再次导入的 JSON（勾选状态不写入） */
export function serializeChecklists(list: AircraftChecklist[]): string {
  return JSON.stringify(
    {
      version: 1,
      aircraft: list.map((aircraft) => ({
        id: aircraft.id,
        name: aircraft.name,
        family: aircraft.family,
        sections: aircraft.sections.map((section) => ({
          phase: section.phase,
          items: section.items.map((item) => ({
            id: item.id,
            task: item.task,
            response: item.response,
            ...(item.detail ? { detail: item.detail } : {}),
          })),
        })),
      })),
    },
    null,
    2,
  );
}
