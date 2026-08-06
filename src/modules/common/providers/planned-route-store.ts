import { create } from 'zustand';
import { AppLogger } from '../../../core/utils/logger';
import { toText } from '../../../core/utils/parse-utils';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import { parsePlannedRoute } from '../services/planned-route-parser';
import type { PlannedRoute } from '../models/planned-route-models';

/**
 * 计划航路（SimBrief 导入）
 *
 * 放在 common/ 而不是 map/ 或 briefing/：**两个模块都要用它** ——
 * 简报负责导入并回填表单，地图负责把航路画出来。全库约定功能模块之间零互引，
 * 跨模块共享的状态一律落在 common/（flight-data-store 就是先例）。
 *
 * 注意这里只管「航路数据」；**是否显示**是地图自己的事，留在 map store 里。
 */

export interface PlannedRouteState {
  /** 已导入的航路；null 表示还没导入过 */
  plan: PlannedRoute | null;
  isImporting: boolean;
  /** 上一次导入失败的原因（来自上游），供界面提示 */
  lastError: string | null;

  /** 从 SimBrief 导入。成功返回航路，失败返回 null */
  importFromSimBrief: (identity: {
    username?: string;
    userId?: string;
  }) => Promise<PlannedRoute | null>;
  clear: () => void;
}

export const usePlannedRouteStore = create<PlannedRouteState>((set) => ({
  plan: null,
  isImporting: false,
  lastError: null,

  async importFromSimBrief(identity) {
    set({ isImporting: true, lastError: null });
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.fetchSimBriefPlan(identity);
      const plan = parsePlannedRoute(response.objectBody?.plan);
      if (!plan) {
        // 后端把上游原因放在 upstream_status（如 "Error: Unknown UserID"）。
        // 只说一句「导入失败」用户无从下手，这里留着给界面显示
        const reason = toText(response.objectBody?.upstream_status).trim();
        AppLogger.warning(`[PlannedRoute] SimBrief import failed${reason ? `: ${reason}` : ''}`);
        set({ isImporting: false, lastError: reason.length > 0 ? reason : null });
        return null;
      }
      set({ plan, isImporting: false, lastError: null });
      return plan;
    } catch (e) {
      AppLogger.warning(`[PlannedRoute] SimBrief import error: ${String(e)}`);
      set({ isImporting: false, lastError: String(e) });
      return null;
    }
  },

  clear: () => set({ plan: null, lastError: null }),
}));
