import type { ModuleRegistrar } from '../../core/module-registry/clearable';
import { ModuleRegistry } from '../../core/module-registry/module-registry';
import { createNavigationItem } from '../../core/module-registry/navigation/navigation-item';
import { registerModuleTranslations, translate } from '../../core/services/localization-service';
import {
  LogViewerLocalizationKeys,
  logViewerTranslations,
} from './localization/log-viewer-localization';
import { LogViewerPage } from './pages/log-viewer-page';

/**
 * LogViewer 模块注册器
 * 对应 Flutter 版 `modules/log_viewer/log_viewer_module.dart`
 */
export class LogViewerModule implements ModuleRegistrar {
  readonly moduleName = 'log_viewer';

  register(): void {
    registerModuleTranslations(logViewerTranslations);

    ModuleRegistry.navigation.register(() =>
      createNavigationItem({
        id: 'log_viewer',
        title: translate(LogViewerLocalizationKeys.navTitle),
        icon: 'notes',
        activeIcon: 'notes',
        page: <LogViewerPage />,
        priority: 100,
        groupId: 'tools',
        // 日志查看不依赖后端
        defaultEnabled: true,
      }),
    );
  }
}
