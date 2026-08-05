import { ModuleRegistry } from '../../core/module-registry/module-registry';
import type { ModuleRegistrar } from '../../core/module-registry/clearable';
import { createNavigationItem } from '../../core/module-registry/navigation/navigation-item';
import { registerModuleTranslations, translate } from '../../core/services/localization-service';
import { HomeLocalizationKeys, homeTranslations } from './localization/home-localization';
import { HomePage } from './pages/home-page';

/**
 * Home 模块注册器
 * 对应 Flutter 版 `modules/home/home_module.dart`
 */
export class HomeModule implements ModuleRegistrar {
  readonly moduleName = 'home';

  register(): void {
    ModuleRegistry.navigation.register(() =>
      createNavigationItem({
        id: 'home',
        title: translate(HomeLocalizationKeys.homeTitle),
        icon: 'home',
        activeIcon: 'home',
        page: <HomePage />,
        priority: 10,
        groupId: 'general',
        // 首页离线也要能进（用于展示后端离线遮罩）
        defaultEnabled: true,
      }),
    );

    registerModuleTranslations(homeTranslations);
  }
}
