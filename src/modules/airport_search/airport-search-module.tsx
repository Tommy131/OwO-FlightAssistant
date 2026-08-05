import type { ModuleRegistrar } from '../../core/module-registry/clearable';
import { ModuleRegistry } from '../../core/module-registry/module-registry';
import { createNavigationItem } from '../../core/module-registry/navigation/navigation-item';
import { registerModuleTranslations, translate } from '../../core/services/localization-service';
import {
  AirportSearchLocalizationKeys,
  airportSearchTranslations,
} from './localization/airport-search-localization';
import { AirportSearchPage } from './pages/airport-search-page';

/**
 * AirportSearch 模块注册器
 * 对应 Flutter 版 `modules/airport_search/airport_search_module.dart`
 */
export class AirportSearchModule implements ModuleRegistrar {
  readonly moduleName = 'airport_search';

  register(): void {
    registerModuleTranslations(airportSearchTranslations);

    ModuleRegistry.navigation.register(() =>
      createNavigationItem({
        id: 'airport_search',
        title: translate(AirportSearchLocalizationKeys.navTitle),
        icon: 'manage_search',
        activeIcon: 'manage_search',
        page: <AirportSearchPage />,
        priority: 13,
        groupId: 'tools',
      }),
    );
  }
}
