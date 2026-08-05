import type { ModuleRegistrar } from '../../core/module-registry/clearable';
import { ModuleRegistry } from '../../core/module-registry/module-registry';
import { createNavigationItem } from '../../core/module-registry/navigation/navigation-item';
import { registerModuleTranslations, translate } from '../../core/services/localization-service';
import { useFlightDataStore } from '../common/providers/flight-data-store';
import {
  MonitorLocalizationKeys,
  monitorTranslations,
} from './localization/monitor-localization';
import { MonitorPage } from './pages/monitor-page';
import { resetMonitorChartBuffer, useMonitorStore } from './providers/monitor-store';

/**
 * Monitor 模块注册器
 *
 * 对应 Flutter 版 `modules/monitor/monitor_module.dart`：
 * 注册翻译、导航项，并把飞行数据快照桥接到监控 store
 * （桌面版是 ChangeNotifierProxyProvider<HomeProvider, MonitorProvider>）。
 */
export class MonitorModule implements ModuleRegistrar {
  readonly moduleName = 'monitor';

  register(): void {
    registerModuleTranslations(monitorTranslations);

    ModuleRegistry.navigation.register(() =>
      createNavigationItem({
        id: 'monitor',
        title: translate(MonitorLocalizationKeys.navTitle),
        icon: 'monitor_heart',
        activeIcon: 'monitor_heart',
        page: <MonitorPage />,
        priority: 30,
        groupId: 'flight',
      }),
    );

    ModuleRegistry.providers.register({
      id: 'monitor_from_flight_data',
      setup: () => {
        void useMonitorStore.getState().loadPerformanceSettings();
        return useFlightDataStore.subscribe((state, previous) => {
          if (state.snapshot === previous.snapshot) return;
          // 模拟器断开时清空图表缓冲，避免重连后时间轴接在旧数据后面
          if (previous.snapshot.isConnected && !state.snapshot.isConnected) {
            resetMonitorChartBuffer();
            return;
          }
          useMonitorStore.getState().updateFromFlightSnapshot(state.snapshot);
        });
      },
    });
  }
}
