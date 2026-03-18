import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/services/localization_service.dart';
import 'localization/airport_search_localization_keys.dart';
import 'localization/airport_search_translations.dart';
import 'pages/airport_search_page.dart';
import 'providers/airport_search_provider.dart';

class AirportSearchModule implements ModuleRegistrar {
  @override
  String get moduleName => 'airport_search';

  @override
  void register() {
    final registry = ModuleRegistry();
    LocalizationService().registerModuleTranslations(airportSearchTranslations);

    registry.providers.register(
      ChangeNotifierProvider(create: (_) => AirportSearchProvider()),
    );

    registry.navigation.register(
      (context) => NavigationItem(
        id: 'airport_search',
        title: AirportSearchLocalizationKeys.navTitle.tr(context),
        icon: Icons.manage_search_outlined,
        activeIcon: Icons.manage_search,
        page: const AirportSearchPage(),
        priority: 13,
        groupId: 'tools',
      ),
    );
  }
}
