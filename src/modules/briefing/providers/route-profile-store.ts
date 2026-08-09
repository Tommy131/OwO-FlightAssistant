/**
 * 航路气象剖面状态
 *
 * 单独一个 store 而不是并进 briefing-store：剖面依赖的是**计划航路**
 * （planned-route-store），跟简报记录的生成/导入/历史是两条互不相干的线。
 * 混在一起会让「导入了 OFP」和「生成过简报」这两个状态互相牵连。
 */

import { create } from 'zustand';
import { AppLogger } from '../../../core/utils/logger';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import type { PlannedRoute } from '../../common/models/planned-route-models';
import type { RouteProfile } from '../models/route-profile-models';
import { parseRouteProfile } from '../services/route-profile-parser';

interface RouteProfileState {
  profile: RouteProfile | null;
  isLoading: boolean;
  /** 失败原因；null 表示没出过错 */
  errorKey: string | null;
  /** 剖面对应的是哪条航路 —— 换了计划就该重取 */
  loadedFor: string | null;

  load: (plan: PlannedRoute) => Promise<void>;
  clear: () => void;
}

/** 航路指纹：航班号 + 起降 + 点数，够区分「换了一份计划」 */
function planKey(plan: PlannedRoute): string {
  return [
    plan.flightNumber ?? '',
    plan.origin.code,
    plan.destination.code,
    plan.points.length,
  ].join('|');
}

export const useRouteProfileStore = create<RouteProfileState>((set, get) => ({
  profile: null,
  isLoading: false,
  errorKey: null,
  loadedFor: null,

  async load(plan) {
    const key = planKey(plan);
    // 同一条航路已经取过就别再打一趟；后端也有 30 分钟缓存，但省一次往返
    if (get().loadedFor === key && get().profile) return;
    if (get().isLoading) return;

    // 起降机场也算航路点：剖面要覆盖到两头，否则跟简报对不上
    const points = [
      { lat: plan.origin.position.latitude, lon: plan.origin.position.longitude },
      ...plan.points.map((point) => ({
        lat: point.position.latitude,
        lon: point.position.longitude,
      })),
      { lat: plan.destination.position.latitude, lon: plan.destination.position.longitude },
    ];
    if (points.length < 2) {
      set({ errorKey: 'not_enough_points', profile: null, loadedFor: null });
      return;
    }

    set({ isLoading: true, errorKey: null });
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getRouteWeatherProfile({
        points,
        enrouteMinutes: plan.enrouteSeconds !== undefined ? plan.enrouteSeconds / 60 : undefined,
      });
      // 后端的成功响应是平铺的（samples 直接在顶层），没有 data 外层
      const profile = parseRouteProfile(response.objectBody);
      if (!profile) {
        set({ isLoading: false, errorKey: 'no_data', profile: null, loadedFor: null });
        return;
      }
      set({ profile, isLoading: false, errorKey: null, loadedFor: key });
    } catch (e) {
      AppLogger.warning(`[Briefing] load route profile failed: ${String(e)}`);
      set({ isLoading: false, errorKey: 'fetch_failed', profile: null, loadedFor: null });
    }
  },

  clear: () => set({ profile: null, errorKey: null, loadedFor: null }),
}));
