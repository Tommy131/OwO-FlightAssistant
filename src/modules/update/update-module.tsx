import type { ModuleRegistrar } from '../../core/module-registry/clearable';
import { ModuleRegistry } from '../../core/module-registry/module-registry';
import { registerModuleTranslations } from '../../core/services/localization-service';
import { AppLogger } from '../../core/utils/logger';
import { updateTranslations } from './localization/update-localization';
import { createUpdateSettingsPageItem } from './pages/update-settings-page-item';
import { runStartupUpdateCheck } from './services/update-flow';
import './styles/update-dialog.css';

/**
 * 启动检查的延迟。
 *
 * 不在注册的瞬间就查：那会儿中间件地址还没读回来，请求多半打空；
 * 而且刚进应用就糊一个弹窗在脸上，体验很差。等首屏稳定下来再说。
 */
const STARTUP_CHECK_DELAY_MS = 4000;

/** 自更新模块：检查发行仓库、弹窗提示、设置页手动检查 */
export class UpdateModule implements ModuleRegistrar {
  readonly moduleName = 'update';

  register(): void {
    registerModuleTranslations(updateTranslations);
    ModuleRegistry.settingsPages.register('software_update_settings', createUpdateSettingsPageItem);

    // 后台跑，失败只记日志 —— 检查更新永远不该拦住应用启动
    setTimeout(() => {
      void runStartupUpdateCheck().catch((e: unknown) => {
        AppLogger.info(`[Update] startup check failed: ${String(e)}`);
      });
    }, STARTUP_CHECK_DELAY_MS);
  }
}
