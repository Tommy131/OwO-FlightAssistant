import { AppConstants } from '../../core/constants/app-constants';
import { AppLogger } from '../../core/utils/logger';
import { ModuleRegistry } from '../../core/module-registry/module-registry';
import type { ModuleRegistrar } from '../../core/module-registry/clearable';
import { createNavigationGroup } from '../../core/module-registry/navigation/navigation-group';
import { registerModuleTranslations, translate } from '../../core/services/localization-service';
import { useFlightLogsStore } from '../flight_logs/providers/flight-logs-store';
import {
  commonModuleTranslations,
  navigationModuleTranslations,
  NavigationLocalizationKeys,
} from './localization/common-localization';
import {
  createBackendStatusTitleBadge,
  createConnectedFlightMiniCard,
  createDefaultMiniCard,
} from './sidebar/sidebar-mini-cards';
import { useAppModeStore } from './providers/app-mode-store';
import { createDefaultFlightDataAdapter, useFlightDataStore } from './providers/flight-data-store';
import { usePlannedRouteStore } from './providers/planned-route-store';
import { useWorkflowStore } from './providers/workflow-store';
import { createAppModeAction } from './widgets/app-mode-action';
import { createWorkflowAction } from './widgets/workflow-action';

/**
 * 公共模块注册器
 *
 * 对应 Flutter 版 `modules/common/common_module.dart`。
 * 负责注册：
 *   - 全局飞行数据 store 与中间件适配器
 *   - 导航可用性规则（后端连通性校验）
 *   - 侧边栏迷你卡片与标题徽章
 *   - 三个导航分组（general / flight / tools）与通用翻译
 */
export class CommonModule implements ModuleRegistrar {
  readonly moduleName = 'common';

  register(): void {
    // ── 全局飞行数据适配器 ──
    const adapter = createDefaultFlightDataAdapter();
    ModuleRegistry.registerCleanup(async () => {
      adapter.dispose();
    });

    // ── 导航可用性：未标记 defaultEnabled 的模块需要后端连通 ──
    // ⚠️ 该 resolver 在组件 render 期间被调用，因此可以直接用 hook 订阅
    ModuleRegistry.navigationAvailability.register((item) => {
      const reachable = useFlightDataStore((s) => s.snapshot.isBackendReachable);
      return item.defaultEnabled || reachable;
    });

    // ── 侧边栏迷你卡片（按优先级取第一个可展示的）──
    ModuleRegistry.sidebarMiniCards.register(
      'connected_flight_mini_card',
      createConnectedFlightMiniCard,
    );
    ModuleRegistry.sidebarMiniCards.register('default_app_mini_card', createDefaultMiniCard);

    // ── 侧边栏标题与后端状态徽章 ──
    ModuleRegistry.sidebarTitle.register('home_sidebar_title', () => AppConstants.appName);
    ModuleRegistry.sidebarTitleBadge.register(
      'home_backend_status_title_badge',
      createBackendStatusTitleBadge,
    );

    // ── 通用文案（首页 + 导航分组）──
    registerModuleTranslations(commonModuleTranslations);
    registerModuleTranslations(navigationModuleTranslations);

    // ── 训练模式 / 复盘模式切换（顶栏常驻）──
    void useAppModeStore.getState().hydrate();
    ModuleRegistry.appBarActions.register('app_mode_switch', createAppModeAction);

    // ── 跨模块任务流入口（顶栏常驻）──
    ModuleRegistry.appBarActions.register('flight_workflow', createWorkflowAction);

    // ── 导航分组 ──
    const navigation = ModuleRegistry.navigation;
    navigation.registerGroup(() =>
      createNavigationGroup({
        id: 'general',
        title: translate(NavigationLocalizationKeys.navGroupGeneral),
        icon: 'dashboard',
        priority: 0,
      }),
    );
    navigation.registerGroup(() =>
      createNavigationGroup({
        id: 'flight',
        title: translate(NavigationLocalizationKeys.navGroupFlight),
        icon: 'flight_takeoff',
        priority: 10,
      }),
    );
    navigation.registerGroup(() =>
      createNavigationGroup({
        id: 'tools',
        title: translate(NavigationLocalizationKeys.navGroupTools),
        icon: 'construction',
        priority: 20,
      }),
    );

    // ── store 绑定：飞行快照 → 飞行日志（等价于 ChangeNotifierProxyProvider）──
    ModuleRegistry.providers.register({
      id: 'flight_logs_from_flight_data',
      setup: () => {
        void useFlightLogsStore.getState().refreshLogs();
        return useFlightDataStore.subscribe((state, previous) => {
          if (state.snapshot === previous.snapshot) return;
          useFlightLogsStore.getState().handleFlightSnapshot(state.snapshot);
        });
      },
    });

    // ── 刷新页面后的会话与录制恢复 ──
    //
    // 顺序有讲究：**先接回连接、再恢复录制**。反过来的话，录制恢复完成的瞬间
    // 快照还是「未连接」，既有的自动收尾逻辑会立刻把这段录制收掉存档，
    // 用户看到的就是「刷新一下，录制自己停了」。
    ModuleRegistry.providers.register({
      id: 'session_recovery',
      setup: () => {
        void (async () => {
          try {
            await useFlightDataStore.getState().resumeSession();
            await useFlightLogsStore.getState().recoverActiveLog();
          } catch (e) {
            AppLogger.warning(`[Common] session recovery failed: ${String(e)}`);
          }
        })();

        // 主动刷新/关页时补一次写盘，补上节流窗口里的最后几秒
        const flush = () => {
          void useFlightLogsStore.getState().flushActiveLog();
        };
        window.addEventListener('beforeunload', flush);
        return () => window.removeEventListener('beforeunload', flush);
      },
    });

    // ── store 绑定：各模块状态 → 任务流进度 ──
    //
    // 任务流的输入横跨四个 store，任何一个变了都要重算；
    // 重算本身很便宜（纯函数），且 workflow-store 内部按输入指纹去重，
    // 不会因为遥测 2Hz 就跟着刷新整棵订阅树。
    ModuleRegistry.providers.register({
      id: 'workflow_progress',
      setup: () => {
        const recompute = () => {
          const snapshot = useFlightDataStore.getState().snapshot;
          const logs = useFlightLogsStore.getState();
          useWorkflowStore.getState().recompute({
            hasDestination: snapshot.destinationAirport !== undefined,
            hasPlannedRoute: usePlannedRouteStore.getState().plan !== null,
            isConnected: snapshot.isConnected,
            hasPosition:
              snapshot.flightData.latitude !== undefined &&
              snapshot.flightData.longitude !== undefined,
            checklistProgress: snapshot.checklistProgress ?? 0,
            isRecording: logs.isRecording,
            savedLogCount: logs.logs.length,
          });
        };
        recompute();
        const disposers = [
          useFlightDataStore.subscribe(recompute),
          useFlightLogsStore.subscribe(recompute),
          usePlannedRouteStore.subscribe(recompute),
        ];
        return () => disposers.forEach((dispose) => dispose());
      },
    });
  }
}
