import type { ModuleRegistrar } from '../../core/module-registry/clearable';
import { ModuleRegistry } from '../../core/module-registry/module-registry';
import { createNavigationItem } from '../../core/module-registry/navigation/navigation-item';
import { LocalizationKeys } from '../../core/localization/localization-keys';
import { translate } from '../../core/services/localization-service';
import { SettingsPage } from '../../core/settings-pages/settings-page';

/**
 * 设置模块注册器
 *
 * 桌面版把设置页挂在侧边栏页脚；Web 版统一收进「工具」分组，
 * 与其它导航项一致。id 保持 `settings` —— 首页的「前往设置」
 * 通过 NavigationCommandBus.goTo('settings') 跳转依赖这个 id。
 */
export class SettingsModule implements ModuleRegistrar {
  readonly moduleName = 'settings';

  register(): void {
    ModuleRegistry.navigation.register(() =>
      createNavigationItem({
        id: 'settings',
        title: translate(LocalizationKeys.settings),
        icon: 'settings',
        activeIcon: 'settings',
        page: <SettingsPage />,
        priority: 200,
        groupId: 'tools',
        // 设置页必须离线可达 —— 后端连不上时正是要来这里改地址
        defaultEnabled: true,
      }),
    );
  }
}
