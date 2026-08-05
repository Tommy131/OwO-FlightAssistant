import type { ModuleRegistrar } from '../../core/module-registry/clearable';
import { ModuleRegistry } from '../../core/module-registry/module-registry';
import { createNavigationItem } from '../../core/module-registry/navigation/navigation-item';
import { registerModuleTranslations, translate } from '../../core/services/localization-service';
import {
  BriefingLocalizationKeys,
  briefingTranslations,
} from './localization/briefing-localization';
import { BriefingPage } from './pages/briefing-page';

/**
 * Briefing 模块注册器
 * 对应 Flutter 版 `modules/briefing/briefing_module.dart`
 */
export class BriefingModule implements ModuleRegistrar {
  readonly moduleName = 'briefing';

  register(): void {
    registerModuleTranslations(briefingTranslations);

    ModuleRegistry.navigation.register(() =>
      createNavigationItem({
        id: 'briefing',
        title: translate(BriefingLocalizationKeys.navTitle),
        icon: 'assignment',
        activeIcon: 'assignment',
        page: <BriefingPage />,
        priority: 15,
        groupId: 'flight',
      }),
    );
  }
}
