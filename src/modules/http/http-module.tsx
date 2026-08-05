import type { ModuleRegistrar } from '../../core/module-registry/clearable';
import { ModuleRegistry } from '../../core/module-registry/module-registry';
import { setBackendTransport } from '../../core/services/backend-transport';
import { registerModuleTranslations } from '../../core/services/localization-service';
import { httpTranslations } from './localization/http-localization';
import { createHttpSettingsPageItem } from './pages/http-settings-page-item';
import { middlewareBackendTransport } from './services/middleware-backend-transport';
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

    // 把传输实现注入 core：core 只声明它需要什么（BackendTransport 接口），
    // 具体怎么发请求由本模块提供。依赖方向保持 modules → core。
    setBackendTransport(middlewareBackendTransport);

    // 提前载入持久化的地址配置，避免首个请求打到默认地址
    void MiddlewareHttpService.init();
  }
}
