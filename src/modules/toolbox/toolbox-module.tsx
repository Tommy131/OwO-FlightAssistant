import { createAppBarSideMenuEntry } from '../../core/module-registry/app-bar/app-bar-action';
import type { ModuleRegistrar } from '../../core/module-registry/clearable';
import { ModuleRegistry } from '../../core/module-registry/module-registry';
import { createNavigationItem } from '../../core/module-registry/navigation/navigation-item';
import { registerModuleTranslations, translate } from '../../core/services/localization-service';
import {
  ToolboxLocalizationKeys,
  toolboxTranslations,
} from './localization/toolbox-localization';
import { TOOLBOX_SECTIONS } from './models/toolbox-models';
import {
  TOOLBOX_SECTION_META,
  ToolboxPage,
  useToolboxSectionStore,
} from './pages/toolbox-page';

/**
 * Toolbox 模块注册器
 *
 * 对应 Flutter 版 `modules/toolbox/toolbox_module.dart`。
 * 6 个分区通过 `AppBarActionRegistry.registerSideMenu` 注册为侧边二级菜单 ——
 * 这是整个框架里「模块向 AppBar 注入二级导航」的唯一用例。
 */
export class ToolboxModule implements ModuleRegistrar {
  readonly moduleName = 'toolbox';

  register(): void {
    registerModuleTranslations(toolboxTranslations);

    ModuleRegistry.navigation.register(() =>
      createNavigationItem({
        id: 'toolbox',
        title: translate(ToolboxLocalizationKeys.toolboxTitle),
        icon: 'build',
        activeIcon: 'build',
        page: <ToolboxPage />,
        priority: 35,
        groupId: 'tools',
        // 工具箱全部为本地计算，离线可用
        defaultEnabled: true,
      }),
    );

    // 6 个分区各注册一个侧边二级菜单项
    for (const section of TOOLBOX_SECTIONS) {
      const meta = TOOLBOX_SECTION_META[section];
      ModuleRegistry.appBarActions.registerSideMenu(`toolbox_side_menu_${section}`, () =>
        createAppBarSideMenuEntry({
          id: `toolbox_side_menu_${section}`,
          navigationId: 'toolbox',
          icon: meta.icon,
          priority: meta.priority,
          getTitle: () => translate(meta.titleKey),
          isSelected: () => useToolboxSectionStore.getState().selectedSection === section,
          onTap: () => useToolboxSectionStore.getState().select(section),
        }),
      );
    }
  }
}
