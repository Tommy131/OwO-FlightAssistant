import { AppConstants } from '../../core/constants/app-constants';
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
import { createDefaultFlightDataAdapter, useFlightDataStore } from './providers/flight-data-store';

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
  }
}
