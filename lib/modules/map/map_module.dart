import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/services/localization_service.dart';
import 'localization/map_localization_keys.dart';
import 'localization/map_translations.dart';
import 'pages/map_page.dart';
import 'providers/map_provider.dart';

class MapModule implements ModuleRegistrar {
  @override
  String get moduleName => 'map';

  @override
  void register() {
    final registry = ModuleRegistry();
    LocalizationService().registerModuleTranslations(mapTranslations);

    registry.providers.register(
      ChangeNotifierProvider(create: (_) => MapProvider()),
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
  }
}
