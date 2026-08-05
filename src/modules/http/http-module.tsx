import type { ModuleRegistrar } from '../../core/module-registry/clearable';
import { ModuleRegistry } from '../../core/module-registry/module-registry';
import { registerModuleTranslations } from '../../core/services/localization-service';
import { httpTranslations } from './localization/http-localization';
import { createHttpSettingsPageItem } from './pages/http-settings-page-item';
import { MiddlewareHttpService } from './services/middleware-http-service';

/**
 * Http 模块注册器
 * 对应 Flutter 版 `modules/http/http_module.dart`：注册翻译与中间件设置页
 */
export class HttpModule implements ModuleRegistrar {
  readonly moduleName = 'http';

  register(): void {
    registerModuleTranslations(httpTranslations);
    ModuleRegistry.settingsPages.register('http_backend_settings', createHttpSettingsPageItem);
    // 提前载入持久化的地址配置，避免首个请求打到默认地址
    void MiddlewareHttpService.init();
  }
}
