import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/services/localization_service.dart';
import '../common/providers/home_provider.dart';
import 'localization/map_localization_keys.dart';
import 'localization/map_translations.dart';
import 'pages/map_page.dart';
import 'pages/map_timer_settings_page_item.dart';
import 'providers/map_provider.dart';

class MapModule implements ModuleRegistrar {
  @override
  String get moduleName => 'map';

  @override
  void register() {
    final registry = ModuleRegistry();
    LocalizationService().registerModuleTranslations(mapTranslations);

    registry.providers.register(
      ChangeNotifierProxyProvider<HomeProvider, MapProvider>(
        create: (_) => MapProvider(),
        update: (_, homeProvider, mapProvider) {
          final provider = mapProvider ?? MapProvider();
          provider.updateFromHomeSnapshot(homeProvider.snapshot);
          return provider;
        },
      ),
    );

    registry.navigation.register(
      (context) => NavigationItem(
        id: 'map',
        title: MapLocalizationKeys.navTitle.tr(context),
        icon: Icons.map_outlined,
        activeIcon: Icons.map,
        page: const MapPage(),
        priority: 25,
      ),
    );

    registry.settingsPages.register(
      'map_module_settings',
      () => MapModuleSettingsPageItem(),
    );
  }
}
