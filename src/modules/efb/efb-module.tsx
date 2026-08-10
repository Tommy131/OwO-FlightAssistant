import type { ModuleRegistrar } from '../../core/module-registry/clearable';
import { ModuleRegistry } from '../../core/module-registry/module-registry';
import { createNavigationItem } from '../../core/module-registry/navigation/navigation-item';
import { registerModuleTranslations, translate } from '../../core/services/localization-service';
import { useFlightDataStore } from '../common/providers/flight-data-store';
import { EfbLocalizationKeys, efbTranslations } from './localization/efb-localization';
import { EfbPage } from './pages/efb-page';
import { useEfbStore } from './providers/efb-store';

/**
 * EFB 飞行卡模块注册器
 *
 * 排在检查单之前（priority 15）：起飞前先看飞行卡确认门限与油量，
 * 再进检查单逐条打勾，与实际操作顺序一致。
 */
export class EfbModule implements ModuleRegistrar {
  readonly moduleName = 'efb';

  register(): void {
    registerModuleTranslations(efbTranslations);

    ModuleRegistry.navigation.register(() =>
      createNavigationItem({
        id: 'efb',
        title: translate(EfbLocalizationKeys.navTitle),
        icon: 'dashboard',
        activeIcon: 'dashboard',
        page: <EfbPage />,
        priority: 15,
        groupId: 'flight',
      }),
    );

    // 断开连接时丢掉近场缓存：留着的话下次连上会先闪一屏上一段航程的机场与气象。
    ModuleRegistry.providers.register({
      id: 'efb_reset_on_disconnect',
      setup: () =>
        useFlightDataStore.subscribe((state, previous) => {
          if (previous.snapshot.isConnected && !state.snapshot.isConnected) {
            useEfbStore.getState().reset();
          }
        }),
    });
  }
}
