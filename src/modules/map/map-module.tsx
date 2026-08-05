import type { ModuleRegistrar } from '../../core/module-registry/clearable';
import { ModuleRegistry } from '../../core/module-registry/module-registry';
import { createNavigationItem } from '../../core/module-registry/navigation/navigation-item';
import { registerModuleTranslations, translate } from '../../core/services/localization-service';
import { useFlightDataStore } from '../common/providers/flight-data-store';
import { MapLocalizationKeys, mapTranslations } from './localization/map-localization';
import { MapPage } from './pages/map-page';
import { createMapSettingsPageItem } from './pages/map-settings-page-item';
import { useMapStore } from './providers/map-store';

/**
 * Map 模块注册器
 *
 * 对应 Flutter 版 `modules/map/map_module.dart`：
 * 注册翻译、导航项、设置页，并把飞行数据快照桥接到地图 store。
 */
export class MapModule implements ModuleRegistrar {
  readonly moduleName = 'map';

  register(): void {
    registerModuleTranslations(mapTranslations);

    ModuleRegistry.navigation.register(() =>
      createNavigationItem({
        id: 'map',
        title: translate(MapLocalizationKeys.navTitle),
        icon: 'map',
        activeIcon: 'map',
        page: <MapPage />,
        priority: 25,
        groupId: 'flight',
      }),
    );

    ModuleRegistry.settingsPages.register('map_module_settings', createMapSettingsPageItem);

    ModuleRegistry.providers.register({
      id: 'map_from_flight_data',
      setup: () => {
        void useMapStore.getState().init();
        return useFlightDataStore.subscribe((state, previous) => {
          if (state.snapshot === previous.snapshot) return;
          useMapStore.getState().updateFromFlightSnapshot(state.snapshot);
        });
      },
    });
  }
}
