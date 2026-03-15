export 'models/http_models.dart';
export 'services/middleware_http_service.dart';

import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/services/localization_service.dart';
import 'localization/http_translations.dart';
import 'pages/http_settings_page_item.dart';
import 'services/middleware_http_service.dart';

class HttpModule implements ModuleRegistrar {
  static final MiddlewareHttpService client = MiddlewareHttpService();

  @override
  String get moduleName => 'http';

  @override
  void register() async {
    final registry = ModuleRegistry();
    LocalizationService().registerModuleTranslations(httpTranslations);
    registry.settingsPages.register(
      'http_backend_settings',
      () => HttpSettingsPageItem(),
    );

    await client.init();
  }
}
