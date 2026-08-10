import { translate } from '../../../core/services/localization-service';
import { toJsonMap, toStringOrUndefined, toText, type JsonMap } from '../../../core/utils/parse-utils';
import type { FlightData } from '../../common/models/common-models';
import { createA320Checklist } from '../data/a320-checklist';
import { createB737Checklist } from '../data/b737-checklist';
import { createGenericChecklist } from '../data/generic-checklist';
import { ChecklistLocalizationKeys } from '../localization/checklist-localization';
import {
  CHECKLIST_PHASES,
  SIMULATOR_TAGS,
  type AircraftChecklist,
  type AircraftFamily,
  type ChecklistItem,
  type ChecklistPhase,
  type SimulatorTag,
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

/** 机型匹配的上下文线索 */
export interface AircraftMatchContext {
  /** 机型线索拼串（标题 / 厂商 / 型号 / ICAO …） */
  identifier?: string;
  /** 机型注册码（尾号），如 B-6075 */
  registration?: string;
  /**
   * 当前连接的模拟器。
   *
   * 收 string 而不是 SimulatorTag：调用方拿到的是后端的原始 `simulatorType`
   * （'xplane' / 'msfs' / 'none'），归一化在 normalizeSimulatorTag 里做。
   */
  simulator?: string;
}

/**
 * 从机型列表中按上下文匹配最合适的检查单。
 *
 * 优先级（高 → 低）：
 *   1. 注册码命中 且 模拟器适用
 *   2. 注册码命中（模拟器不限）
 *   3. ID/名称包含 且 模拟器适用
 *   4. ID/名称包含
 *   5. 家族模糊识别（同样先看模拟器）
 *   6. 通用机型 → 列表首项
 *
 * 注册码排在最前是因为它唯一：机型名能匹配一整个机队，注册码只对应一架飞机，
 * 用户为某架飞机专门写的检查单不该被泛化的机型模板盖掉。
 */
export function resolveAircraft(
  context: AircraftMatchContext | string | undefined,
  aircraftList: AircraftChecklist[],
): AircraftChecklist | null {
  if (aircraftList.length === 0) return null;
  const resolved: AircraftMatchContext =
    typeof context === 'string' || context === undefined ? { identifier: context } : context;

  const simulator = normalizeSimulatorTag(resolved.simulator);
  const registration = normalizeRegistration(resolved.registration);
  const normalized = (resolved.identifier ?? '').trim().toLowerCase();

  // 1 & 2：注册码
  if (registration.length > 0) {
    const byRegistration = aircraftList.filter((aircraft) =>
      (aircraft.registrations ?? []).some(
        (entry) => normalizeRegistration(entry) === registration,
      ),
    );
    const best = bestForSimulator(byRegistration, simulator);
    if (best) return best;
  }

  if (normalized.length === 0) {
    return preferForSimulator(aircraftList, simulator, (list) => findGeneric(list)) ?? aircraftList[0];
  }

  // 3 & 4：ID / 名称包含
  const byName = aircraftList.filter((aircraft) => {
    const id = aircraft.id.toLowerCase();
    const name = aircraft.name.toLowerCase();
    return normalized.includes(id) || normalized.includes(name);
  });
  const bestByName = bestForSimulator(byName, simulator);
  if (bestByName) return bestByName;

  // 5：家族模糊匹配
  const family: AircraftFamily | null = looksLikeB737(normalized)
    ? 'b737'
    : looksLikeA320(normalized)
      ? 'a320'
      : null;
  if (family) {
    const matched = preferForSimulator(aircraftList, simulator, (list) =>
      findByFamily(family, list),
    );
    if (matched) return matched;
  }

  // 6：通用机型兜底
  return (
    preferForSimulator(aircraftList, simulator, (list) => findGeneric(list)) ?? aircraftList[0]
  );
}

/** 先在「适用当前模拟器」的子集里找，找不到再在全集里找 */
function preferForSimulator(
  list: AircraftChecklist[],
  simulator: SimulatorTag,
  pick: (candidates: AircraftChecklist[]) => AircraftChecklist | null,
): AircraftChecklist | null {
  const scoped = list.filter((aircraft) => appliesToSimulator(aircraft, simulator));
  const preferred = pick(scoped);
  if (preferred) return preferred;
  return pick(list);
}

/**
 * 在同一优先级的候选里按模拟器契合度挑最好的一份。
 *
 * 「显式点名了当前模拟器」要赢过「没写 = 不限」：用户特意为 MSFS 写了一份，
 * 就是因为通用那份在 MSFS 上不对；把通用那份挑出来等于白写。
 */
function bestForSimulator(
  candidates: AircraftChecklist[],
  simulator: SimulatorTag,
): AircraftChecklist | null {
  if (candidates.length === 0) return null;
  let best: AircraftChecklist | null = null;
  let bestScore = -1;
  for (const aircraft of candidates) {
    const score = simulatorMatchScore(aircraft, simulator);
    if (score > bestScore) {
      best = aircraft;
      bestScore = score;
    }
  }
  return best;
}

/** 2=显式点名当前模拟器，1=未限制，0=点名了别的模拟器 */
function simulatorMatchScore(aircraft: AircraftChecklist, simulator: SimulatorTag): number {
  const tags = aircraft.simulators ?? [];
  if (tags.length === 0 || tags.includes('any')) return 1;
  if (simulator !== 'any' && tags.includes(simulator)) return 2;
  return 0;
}

/** 判断检查单是否适用于给定模拟器；未声明 simulators 视为不限 */
export function appliesToSimulator(
  aircraft: AircraftChecklist,
  simulator: SimulatorTag,
): boolean {
  const tags = aircraft.simulators ?? [];
  if (tags.length === 0 || tags.includes('any')) return true;
  if (simulator === 'any') return true;
  return tags.includes(simulator);
}

/** 归一化模拟器标签，认不出来的一律当 any */
export function normalizeSimulatorTag(raw: string | undefined): SimulatorTag {
  const value = (raw ?? '').trim().toLowerCase();
  if (value === 'xplane' || value === 'x-plane' || value.startsWith('xplane')) return 'xplane';
  if (value === 'msfs' || value.startsWith('msfs')) return 'msfs';
  return 'any';
}

/**
 * 归一化注册码：去掉横杠与空格后转大写。
 *
 * 同一架飞机在不同模拟器里写法不一（B-6075 / B6075 / b 6075），
 * 不归一化就会出现「明明填了注册码却匹配不上」。
 */
export function normalizeRegistration(raw: string | undefined): string {
  return (raw ?? '').replace(/[\s-]/g, '').toUpperCase();
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
        const phase = normalizePhase(toText(sectionMap.phase));
        const itemsRaw = Array.isArray(sectionMap.items) ? sectionMap.items : [];
        const items: ChecklistItem[] = itemsRaw
          .map((item) => toJsonMap(item))
          .filter((item): item is JsonMap => item !== null)
          .map((itemMap, index) => ({
            id: toText(itemMap.id) || `${phase}_${index}`,
            task: toText(itemMap.task),
            response: toText(itemMap.response),
            detail: toStringOrUndefined(itemMap.detail),
            isChecked: false,
          }))
          .filter((item) => item.task.length > 0);
        return { phase, items };
      })
      .filter((section) => section.items.length > 0);

    if (sections.length === 0) continue;
    const name = toText(map.name) || baseName;
    result.push({
      id: toText(map.id) || slugify(name),
      name,
      family: normalizeFamily(map.family, name),
      sections,
      version: toStringOrUndefined(map.version),
      registrations: parseRegistrations(map.registrations ?? map.registration),
      simulators: parseSimulatorTags(map.simulators ?? map.simulator),
    });
  }
  return result;
}

/** 解析注册码字段：接受数组或逗号分隔的字符串 */
function parseRegistrations(raw: unknown): string[] | undefined {
  const values = toStringList(raw);
  if (values.length === 0) return undefined;
  const seen = new Set<string>();
  const out: string[] = [];
  for (const value of values) {
    const key = normalizeRegistration(value);
    if (key.length === 0 || seen.has(key)) continue;
    seen.add(key);
    // 存原样写法，展示时用户看得懂；比较时才归一化
    out.push(value.trim().toUpperCase());
  }
  return out.length > 0 ? out : undefined;
}

/** 解析适用模拟器字段：接受数组或逗号分隔的字符串 */
function parseSimulatorTags(raw: unknown): SimulatorTag[] | undefined {
  const values = toStringList(raw);
  if (values.length === 0) return undefined;
  const tags = new Set<SimulatorTag>();
  for (const value of values) {
    const tag = normalizeSimulatorTag(value);
    // 认不出的写法会被归一成 any，这时若原文不是 any 就当作没写，
    // 免得把「打错的机型名」变成「不限模拟器」
    if (tag === 'any' && value.trim().toLowerCase() !== 'any') continue;
    tags.add(tag);
  }
  if (tags.size === 0) return undefined;
  return SIMULATOR_TAGS.filter((tag) => tags.has(tag));
}

/** 把「数组 / 逗号分隔字符串」统一成字符串数组 */
function toStringList(raw: unknown): string[] {
  if (Array.isArray(raw)) {
    return raw.map((item) => toText(item)).filter((item) => item.trim().length > 0);
  }
  const text = toText(raw);
  if (text.trim().length === 0) return [];
  return text
    .split(/[,;、]/)
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
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
  const meta = new Map<string, string>();

  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line.length === 0) continue;

    // 头部元数据写在注释里：`# version: 1.0`、`# registration: B-6075, B-6076`
    // 放注释里是为了让老版本解析器原样跳过，不至于把它当成一条检查项。
    if (line.startsWith('#') || line.startsWith('//')) {
      const comment = line.replace(/^(#+|\/\/)\s*/, '');
      const separator = comment.indexOf(':');
      if (separator > 0) {
        const key = comment.slice(0, separator).trim().toLowerCase();
        const value = comment.slice(separator + 1).trim();
        if (value.length > 0) meta.set(key, value);
      }
      continue;
    }

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

  const name = meta.get('name') ?? baseName;
  return [
    {
      id: meta.get('id') ?? slugify(name),
      name,
      family: normalizeFamily(meta.get('family'), name),
      sections,
      version: meta.get('version'),
      registrations: parseRegistrations(meta.get('registrations') ?? meta.get('registration')),
      simulators: parseSimulatorTags(meta.get('simulators') ?? meta.get('simulator')),
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
  const value = toText(raw).toLowerCase();
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

/** 导出文件的格式版本，与单个机型模板自带的 version 是两回事 */
export const CHECKLIST_FILE_FORMAT_VERSION = 2;

/** 序列化为可再次导入的 JSON（勾选状态不写入） */
export function serializeChecklists(list: AircraftChecklist[]): string {
  return JSON.stringify(
    {
      version: CHECKLIST_FILE_FORMAT_VERSION,
      aircraft: list.map((aircraft) => ({
        id: aircraft.id,
        name: aircraft.name,
        family: aircraft.family,
        ...(aircraft.version ? { version: aircraft.version } : {}),
        ...(aircraft.registrations?.length ? { registrations: aircraft.registrations } : {}),
        ...(aircraft.simulators?.length ? { simulators: aircraft.simulators } : {}),
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

// ──────────────────────────────────────────────────────────────────────────
// 默认模板
// ──────────────────────────────────────────────────────────────────────────

/**
 * 生成一份可直接下载、填完就能导入的检查单模板。
 *
 * 模板本身就是合法的导入文件：里面预置了每个飞行阶段的空节段与一两条示例，
 * 用户照着往下写即可。全靠文档描述格式的话，第一次导入基本一定会失败。
 *
 * `seed` 通常传当前连接的机型名，方便用户直接在此基础上改。
 */
export function buildChecklistTemplate(seed?: string): string {
  const name = (seed ?? '').trim() || 'My Aircraft';
  const template = {
    version: CHECKLIST_FILE_FORMAT_VERSION,
    _readme: [
      '每个机型一个对象；下列字段的含义：',
      'id           唯一标识，重复导入时按它覆盖',
      'name         显示名称',
      'version      模板版本号，自己维护',
      'family       机型家族：generic / a320 / b737',
      'registrations 机型注册码（尾号）列表，匹配优先级最高',
      'simulators   适用模拟器：any / xplane / msfs，可多选',
      'sections     按飞行阶段分节；phase 取值见下方各节',
      'items        task=要做的动作，response=标准应答，detail=可选补充说明',
    ],
    aircraft: [
      {
        id: slugify(name),
        name,
        version: '1.0',
        family: inferFamily(name),
        registrations: ['B-0000'],
        simulators: ['any'],
        sections: CHECKLIST_PHASES.map((phase) => ({
          phase,
          items:
            phase === 'coldAndDark'
              ? [
                  {
                    id: 'example_battery',
                    task: 'BATTERY',
                    response: 'ON',
                    detail: '示例条目，可删除',
                  },
                  { id: 'example_beacon', task: 'BEACON LIGHT', response: 'ON' },
                ]
              : [],
        })),
      },
    ],
  };
  return JSON.stringify(template, null, 2);
}
