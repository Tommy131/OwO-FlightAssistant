import { create } from 'zustand';
import { PersistenceService } from '../../../core/services/persistence-service';
import { AppLogger } from '../../../core/utils/logger';
import { toJsonMap } from '../../../core/utils/parse-utils';
import type { FlightData } from '../../common/models/common-models';
import { useFlightDataStore } from '../../common/providers/flight-data-store';
import { ChecklistLocalizationKeys } from '../localization/checklist-localization';
import {
  cloneChecklist,
  findSection,
  phaseProgress,
  type AircraftChecklist,
  type ChecklistPhase,
} from '../models/flight-checklist';
import { evaluateAutoChecks } from '../services/checklist-auto-check';
import {
  buildChecklistTemplate,
  derivePhase,
  getBuiltInChecklists,
  parseChecklistFile,
  resolveAircraft,
  serializeChecklists,
  shouldApplyPhase,
  type AircraftMatchContext,
} from '../services/checklist-services';
import { translate } from '../../../core/services/localization-service';

/**
 * 检查单状态管理
 *
 * 对应 Flutter 版 `modules/checklist/providers/checklist_provider.dart`。
 *
 * ── Web 降级说明 ──
 * 桌面版从「用户检查单目录」扫描 json/txt/csv 文件；浏览器没有目录概念，
 * 因此改为：导入的检查单持久化到 IndexedDB，「刷新配置」= 从 IndexedDB 重载。
 * 导入导出的文件格式与桌面版完全一致，两端可互相搬运。
 */

const MODULE_NAME = 'checklist';
const IMPORTED_KEY = 'imported_checklists';

interface ChecklistState {
  aircraftList: AircraftChecklist[];
  selectedAircraft: AircraftChecklist | null;
  currentPhase: ChecklistPhase;
  isLoading: boolean;

  /** 上次请求匹配的上下文，加载完成后据此自动选中 */
  pendingMatch?: AircraftMatchContext;

  /**
   * 由遥测自动勾选/取消的条目 id
   * 供 UI 打标，让飞行员分得清哪些是自己勾的、哪些是模拟器同步来的。
   */
  autoCheckedIds: ReadonlySet<string>;
  /**
   * 被用户手动改过的条目 id
   * 这些条目不再接受自动同步 —— 人工判断优先于遥测。
   */
  manualOverrideIds: ReadonlySet<string>;

  init: () => Promise<void>;
  selectAircraft: (id: string) => void;
  /** 按机型线索 / 注册码 / 模拟器自动切换检查单 */
  updateAircraftByIdentifier: (context: AircraftMatchContext | string | undefined) => boolean;
  setPhase: (phase: ChecklistPhase) => void;
  syncWithFlightData: (flightData: FlightData) => void;
  toggleItem: (itemId: string) => void;
  /** 把手动改过的条目交还给遥测自动同步 */
  releaseManualOverride: (itemId: string) => void;
  resetCurrentPhase: () => void;
  resetAll: () => void;
  getPhaseProgress: (phase: ChecklistPhase) => number;

  /** 从 IndexedDB 重新载入；无外部配置时回退内建。返回外部机型数量 */
  reload: (fallbackToBuiltIn?: boolean) => Promise<number>;
  /** 导入文件。返回 >0 成功条数，0 解析失败 */
  importFromFile: (file: File) => Promise<number>;
  /** 导出为 JSON 文件。返回 1 成功，-1 无数据 */
  exportToFile: () => number;
  /** 下载一份可直接填写的空白模板 */
  downloadTemplate: () => void;
}

export const useChecklistStore = create<ChecklistState>((set, get) => ({
  aircraftList: [],
  selectedAircraft: null,
  currentPhase: 'coldAndDark',
  isLoading: false,
  autoCheckedIds: new Set<string>(),
  manualOverrideIds: new Set<string>(),

  async init() {
    await get().reload(true);
    get().updateAircraftByIdentifier(get().pendingMatch);
  },

  // ── 机型选择 ──

  selectAircraft(id) {
    const target = get().aircraftList.find((aircraft) => aircraft.id === id);
    if (!target) return;
    set({ selectedAircraft: target, currentPhase: 'coldAndDark' });
  },

  updateAircraftByIdentifier(context) {
    const match: AircraftMatchContext =
      typeof context === 'string' || context === undefined ? { identifier: context } : context;
    set({ pendingMatch: match });
    const state = get();
    if (state.isLoading || state.aircraftList.length === 0) return false;

    // 完全没有线索：仅在尚未选中任何机型时用它挑默认值，
    // 否则会把用户手动选择的机型冲回「通用机型」。
    const hasClue =
      (match.identifier ?? '').trim().length > 0 || (match.registration ?? '').trim().length > 0;
    if (!hasClue && state.selectedAircraft !== null) {
      return false;
    }

    const selected = resolveAircraft(match, state.aircraftList);
    if (!selected) return false;
    if (state.selectedAircraft?.id === selected.id) return true;

    set({ selectedAircraft: selected, currentPhase: 'coldAndDark' });
    return true;
  },

  // ── 飞行阶段 ──

  setPhase(phase) {
    set({ currentPhase: phase });
  },

  syncWithFlightData(flightData) {
    const state = get();
    const selected = state.selectedAircraft;
    if (!selected) return;

    // ── 1. 阶段推导 ──
    const nextPhase = derivePhase(flightData);
    if (nextPhase && nextPhase !== state.currentPhase && shouldApplyPhase(state.currentPhase, nextPhase)) {
      set({ currentPhase: nextPhase });
    }

    // ── 2. 条目状态跟随遥测 ──
    const verdicts = evaluateAutoChecks(selected, flightData);
    if (verdicts.size === 0) return;

    const autoChecked = new Set(state.autoCheckedIds);
    let changed = false;

    const sections = selected.sections.map((section) => {
      let sectionChanged = false;
      const items = section.items.map((item) => {
        const verdict = verdicts.get(item.id);
        // 无判定（数据缺失）或用户手动改过 → 保持原样
        if (verdict === undefined || state.manualOverrideIds.has(item.id)) return item;
        if (verdict) autoChecked.add(item.id);
        else autoChecked.delete(item.id);
        if (item.isChecked === verdict) return item;
        sectionChanged = true;
        return { ...item, isChecked: verdict };
      });
      if (!sectionChanged) return section;
      changed = true;
      return { ...section, items };
    });

    if (!changed) {
      // 勾选值没变，但打标集合可能变了（例如条目刚进入自动管辖范围）
      if (autoChecked.size !== state.autoCheckedIds.size) set({ autoCheckedIds: autoChecked });
      return;
    }

    const next: AircraftChecklist = { ...selected, sections };
    set({
      selectedAircraft: next,
      aircraftList: replaceInList(state.aircraftList, next),
      autoCheckedIds: autoChecked,
    });
  },

  // ── 条目操作 ──

  toggleItem(itemId) {
    const selected = get().selectedAircraft;
    if (!selected) return;

    // 不可变更新：只重建被改动的 item / section
    let changed = false;
    const next: AircraftChecklist = {
      ...selected,
      sections: selected.sections.map((section) => {
        if (!section.items.some((item) => item.id === itemId)) return section;
        changed = true;
        return {
          ...section,
          items: section.items.map((item) =>
            item.id === itemId ? { ...item, isChecked: !item.isChecked } : item,
          ),
        };
      }),
    };
    if (!changed) return;

    // 手动点过就退出自动同步，避免下一帧遥测又把它改回去
    const manualOverrideIds = new Set(get().manualOverrideIds);
    manualOverrideIds.add(itemId);
    const autoCheckedIds = new Set(get().autoCheckedIds);
    autoCheckedIds.delete(itemId);

    set({
      selectedAircraft: next,
      aircraftList: replaceInList(get().aircraftList, next),
      manualOverrideIds,
      autoCheckedIds,
    });
  },

  releaseManualOverride(itemId) {
    const state = get();
    if (!state.manualOverrideIds.has(itemId)) return;
    const manualOverrideIds = new Set(state.manualOverrideIds);
    manualOverrideIds.delete(itemId);
    set({ manualOverrideIds });
    // 交还之后立刻按最近一帧遥测校正一次，不用干等下一帧推送
    const snapshot = useFlightDataStore.getState().snapshot;
    get().syncWithFlightData(snapshot.flightData);
  },

  resetCurrentPhase() {
    const state = get();
    const selected = state.selectedAircraft;
    if (!selected) return;
    if (!findSection(selected, state.currentPhase)) return;

    const section = findSection(selected, state.currentPhase);
    const next: AircraftChecklist = {
      ...selected,
      sections: selected.sections.map((item) =>
        item.phase === state.currentPhase
          ? { ...item, items: item.items.map((entry) => ({ ...entry, isChecked: false })) }
          : item,
      ),
    };

    // 重置本阶段 = 交还给遥测：撤掉这些条目的手动标记，自动同步随后接管
    const manualOverrideIds = new Set(state.manualOverrideIds);
    const autoCheckedIds = new Set(state.autoCheckedIds);
    for (const entry of section?.items ?? []) {
      manualOverrideIds.delete(entry.id);
      autoCheckedIds.delete(entry.id);
    }

    set({
      selectedAircraft: next,
      aircraftList: replaceInList(state.aircraftList, next),
      manualOverrideIds,
      autoCheckedIds,
    });
  },

  resetAll() {
    const selected = get().selectedAircraft;
    if (!selected) return;
    const next: AircraftChecklist = {
      ...selected,
      sections: selected.sections.map((section) => ({
        ...section,
        items: section.items.map((item) => ({ ...item, isChecked: false })),
      })),
    };
    set({
      selectedAircraft: next,
      aircraftList: replaceInList(get().aircraftList, next),
      currentPhase: 'coldAndDark',
      manualOverrideIds: new Set(),
      autoCheckedIds: new Set(),
    });
  },

  getPhaseProgress(phase) {
    return phaseProgress(get().selectedAircraft, phase);
  },

  // ── 加载与文件操作 ──

  async reload(fallbackToBuiltIn = true) {
    set({ isLoading: true, selectedAircraft: null });
    try {
      await PersistenceService.ensureReady();
      const stored = PersistenceService.getModuleData<unknown[]>(MODULE_NAME, IMPORTED_KEY);

      const imported: AircraftChecklist[] = Array.isArray(stored)
        ? stored
            .map((item) => toJsonMap(item))
            .filter((item): item is Record<string, unknown> => item !== null)
            .flatMap((item) => parseChecklistFile('stored.json', JSON.stringify(item)))
        : [];

      if (imported.length === 0 && fallbackToBuiltIn) {
        applyAircraftList(set, get, getBuiltInChecklists());
        set({ isLoading: false });
        return 0;
      }

      // 外部配置与内建并存，外部同 id 覆盖内建
      const merged = mergeById([...getBuiltInChecklists(), ...imported]);
      applyAircraftList(set, get, merged);
      set({ isLoading: false });
      get().updateAircraftByIdentifier(get().pendingMatch);
      return imported.length;
    } catch (e) {
      AppLogger.error('[Checklist] reload failed', e);
      applyAircraftList(set, get, getBuiltInChecklists());
      set({ isLoading: false });
      return 0;
    }
  },

  async importFromFile(file) {
    const content = await file.text();
    const loaded = parseChecklistFile(file.name, content);
    if (loaded.length === 0) return 0;

    const merged = mergeById([...get().aircraftList, ...loaded]);
    set({ aircraftList: merged });

    // 用文件名作为线索自动选中刚导入的机型
    const hint = file.name.replace(/\.[^.]+$/, '');
    const selected = resolveAircraft(hint, merged) ?? get().selectedAircraft;
    if (selected) set({ selectedAircraft: selected, currentPhase: 'coldAndDark' });

    // 只持久化非内建的部分
    const builtInIds = new Set(getBuiltInChecklists().map((item) => item.id));
    const toPersist = merged.filter((item) => !builtInIds.has(item.id));
    await PersistenceService.setModuleData(
      MODULE_NAME,
      IMPORTED_KEY,
      (JSON.parse(serializeChecklists(toPersist)) as { aircraft: unknown[] }).aircraft,
    );

    return loaded.length;
  },

  exportToFile() {
    const list = get().aircraftList;
    if (list.length === 0) return -1;
    downloadJson(serializeChecklists(list), 'checklist_export.json');
    return 1;
  },

  downloadTemplate() {
    // 用当前连接的机型名作种子：模板里的 id/name/family 就已经填对了，
    // 用户只要补条目，少一步猜格式。
    const seed = useFlightDataStore.getState().snapshot.aircraftTitle;
    downloadJson(buildChecklistTemplate(seed), 'checklist_template.json');
  },
}));

/** 触发浏览器下载一段 JSON 文本 */
function downloadJson(content: string, fileName: string): void {
  const blob = new Blob([content], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  URL.revokeObjectURL(url);
}

// ──────────────────────────────────────────────────────────────────────────
// 内部辅助
// ──────────────────────────────────────────────────────────────────────────

type Setter = (partial: Partial<ChecklistState>) => void;
type Getter = () => ChecklistState;

/** 替换机型列表，尽量保留当前已选机型 */
function applyAircraftList(set: Setter, get: Getter, list: AircraftChecklist[]): void {
  // 每次装载都深拷贝，避免不同机型间共享 item 引用
  const cloned = list.map(cloneChecklist);
  if (cloned.length === 0) {
    set({ aircraftList: [], selectedAircraft: null });
    return;
  }

  const selectedId = get().selectedAircraft?.id;
  const keep = selectedId ? cloned.find((aircraft) => aircraft.id === selectedId) : undefined;
  set({
    aircraftList: cloned,
    selectedAircraft: keep ?? cloned[0],
    currentPhase: 'coldAndDark',
  });
}

/** 按 id 去重合并（后者覆盖前者），并按名称排序 */
function mergeById(list: AircraftChecklist[]): AircraftChecklist[] {
  const byId = new Map<string, AircraftChecklist>();
  for (const aircraft of list) byId.set(aircraft.id, aircraft);
  return [...byId.values()].sort((a, b) => a.name.localeCompare(b.name));
}

function replaceInList(
  list: AircraftChecklist[],
  next: AircraftChecklist,
): AircraftChecklist[] {
  return list.map((aircraft) => (aircraft.id === next.id ? next : aircraft));
}

/** 「刷新配置」的结果文案（供页面直接使用） */
export function refreshResultMessage(count: number): string {
  return count > 0
    ? translate(ChecklistLocalizationKeys.refreshSuccess, count)
    : translate(ChecklistLocalizationKeys.refreshEmpty);
}
