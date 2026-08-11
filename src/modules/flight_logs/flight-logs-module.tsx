import type { ModuleRegistrar } from '../../core/module-registry/clearable';
import { ModuleRegistry } from '../../core/module-registry/module-registry';
import { createNavigationItem } from '../../core/module-registry/navigation/navigation-item';
import { registerModuleTranslations, translate } from '../../core/services/localization-service';
import { landingFlareTranslations } from './localization/landing-flare-localization';
import {
  FlightLogsLocalizationKeys,
  flightLogsTranslations,
} from './localization/flight-logs-localization';
import { FlightLogsPage } from './pages/flight-logs-page';

/**
 * FlightLogs 模块注册器
 *
 * 对应 Flutter 版 `modules/flight_logs/flight_logs_module.dart`。
 * 飞行快照 → 日志记录的订阅绑定在 CommonModule 中注册
 * （因为侧边栏迷你卡片也要读 isRecording，绑定必须早于本模块）。
 */
export class FlightLogsModule implements ModuleRegistrar {
  readonly moduleName = 'flight_logs';

  register(): void {
    registerModuleTranslations(flightLogsTranslations);
    registerModuleTranslations(landingFlareTranslations);

    ModuleRegistry.navigation.register(() =>
      createNavigationItem({
        id: 'flight_logs',
        title: translate(FlightLogsLocalizationKeys.navTitle),
        icon: 'receipt_long',
        activeIcon: 'receipt_long',
        page: <FlightLogsPage />,
        priority: 40,
        groupId: 'flight',
        // 离线也能查看历史日志
        defaultEnabled: true,
      }),
    );
  }
}
