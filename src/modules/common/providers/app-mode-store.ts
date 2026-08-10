import { create } from 'zustand';

import { PersistenceService } from '../../../core/services/persistence-service';
import { AppLogger } from '../../../core/utils/logger';

/**
 * 应用模式：实时辅助 vs 事后复盘
 *
 * ── 为什么要显式分开 ──
 * 两种场景对同一份界面的期望是反的：
 *
 * - **训练模式（live）**：飞行中用。检查单跟着遥测自动打勾、EFB 拉近场气象、
 *   地图跟着飞机走。信息越自动越好，因为手上在忙。
 * - **复盘模式（review）**：落地后用。这时候自动化全是干扰 —— 你正对着一条
 *   航段慢慢翻，检查单却因为「现在飞机停着」把阶段刷回冷舱、EFB 每分钟去打一次
 *   NOAA。更糟的是分不清屏幕上的数是刚才那次飞的、还是此刻模拟器里的。
 *
 * 所以复盘模式下要主动关掉实时联动，让界面停在用户选定的那一刻。
 */

/** 应用模式 */
export type AppMode = 'live' | 'review';

const MODULE_NAME = 'app';
const MODE_KEY = 'app_mode';

interface AppModeState {
  mode: AppMode;
  /** 是否已从持久化载入过 */
  hydrated: boolean;

  /** 从持久化恢复上次的模式（幂等） */
  hydrate: () => Promise<void>;
  setMode: (mode: AppMode) => Promise<void>;
  toggle: () => Promise<void>;
}

export const useAppModeStore = create<AppModeState>((set, get) => ({
  // 默认实时：绝大多数时候用户是打开程序准备起飞，不是来复盘的。
  mode: 'live',
  hydrated: false,

  async hydrate() {
    if (get().hydrated) return;
    try {
      await PersistenceService.ensureReady();
      const stored = PersistenceService.getModuleData<string>(MODULE_NAME, MODE_KEY);
      set({ mode: normalizeMode(stored), hydrated: true });
    } catch (e) {
      AppLogger.warning(`[AppMode] hydrate failed: ${String(e)}`);
      set({ hydrated: true });
    }
  },

  async setMode(mode) {
    if (get().mode === mode) return;
    set({ mode });
    try {
      await PersistenceService.setModuleData(MODULE_NAME, MODE_KEY, mode);
    } catch (e) {
      AppLogger.warning(`[AppMode] persist failed: ${String(e)}`);
    }
  },

  async toggle() {
    await get().setMode(get().mode === 'live' ? 'review' : 'live');
  },
}));

/** 当前是否处于复盘模式（供订阅回调等非组件场景直接读） */
export function isReviewMode(): boolean {
  return useAppModeStore.getState().mode === 'review';
}

function normalizeMode(raw: unknown): AppMode {
  return raw === 'review' ? 'review' : 'live';
}
