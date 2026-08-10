import { create } from 'zustand';

import { AppLogger } from '../../../core/utils/logger';
import {
  fetchUpdateProgress,
  fetchUpdateState,
  ignoreUpdate,
  startUpdateInstall,
} from '../services/update-api';
import type { UpdateProgress, UpdateState } from '../services/update-model';

/** 自更新进度的轮询间隔 */
const PROGRESS_POLL_MS = 700;

interface UpdateStoreState {
  /** 最近一次检查的结果 */
  state?: UpdateState;
  /** 正在检查 */
  checking: boolean;
  /** 自更新进度；没在装的时候为 undefined */
  progress?: UpdateProgress;
  /** 启动时的那次检查是否已经跑过（用来保证只自动弹一次） */
  startupChecked: boolean;

  check: (force: boolean) => Promise<UpdateState | undefined>;
  ignore: (tag: string) => Promise<void>;
  unignore: () => Promise<void>;
  install: (tag: string) => Promise<boolean>;
  markStartupChecked: () => void;
}

let pollHandle: ReturnType<typeof setInterval> | null = null;

export const useUpdateStore = create<UpdateStoreState>((set, get) => ({
  checking: false,
  startupChecked: false,

  async check(force) {
    if (get().checking) return get().state;
    set({ checking: true });
    try {
      const state = await fetchUpdateState(force);
      set({ state });
      return state;
    } finally {
      set({ checking: false });
    }
  },

  async ignore(tag) {
    const ok = await ignoreUpdate(tag);
    if (!ok) return;
    // 本地立刻反映，不必等下一次检查 —— 用户点完「忽略」界面就该变
    set((s) => (s.state ? { state: { ...s.state, ignoredTag: tag, ignored: true } } : {}));
  },

  async unignore() {
    const ok = await ignoreUpdate('');
    if (!ok) return;
    set((s) => (s.state ? { state: { ...s.state, ignoredTag: '', ignored: false } } : {}));
  },

  async install(tag) {
    const started = await startUpdateInstall(tag);
    if (!started) return false;
    set({ progress: { phase: 'downloading', tag, downloadedBytes: 0, totalBytes: 0 } });
    startProgressPolling(set);
    return true;
  },

  markStartupChecked() {
    set({ startupChecked: true });
  },
}));

/**
 * 轮询自更新进度。
 *
 * 中间件替换完自己会重启，这期间请求必然失败 —— 那不是错误而是预期，
 * 所以拿不到进度就停在最后一帧，不要把它当成失败弹给用户。
 */
function startProgressPolling(set: (partial: Partial<UpdateStoreState>) => void): void {
  stopProgressPolling();
  let missedPolls = 0;
  pollHandle = setInterval(() => {
    void (async () => {
      const progress = await fetchUpdateProgress();
      if (!progress) {
        missedPolls++;
        // 连着几次都问不到：中间件多半已经退出去换 exe 了
        if (missedPolls >= 3) {
          AppLogger.info('[Update] middleware stopped responding, assuming restart in progress');
          set({ progress: { phase: 'restarting', downloadedBytes: 0, totalBytes: 0 } });
          stopProgressPolling();
        }
        return;
      }
      missedPolls = 0;
      set({ progress });
      if (progress.phase === 'failed' || progress.phase === 'restarting') {
        stopProgressPolling();
      }
    })();
  }, PROGRESS_POLL_MS);
}

function stopProgressPolling(): void {
  if (pollHandle !== null) {
    clearInterval(pollHandle);
    pollHandle = null;
  }
}
