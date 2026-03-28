import 'package:flutter/material.dart';

import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/services/localization_service.dart';
import 'localization/home_localization_keys.dart';
import 'localization/home_translations.dart';
import 'pages/home_page.dart';

class HomeModule implements ModuleRegistrar {
  @override
  String get moduleName => 'home';

  @override
  void register() {
    final registry = ModuleRegistry();

    registry.navigation.register(
      (context) => NavigationItem(
        id: 'home',
        title: HomeLocalizationKeys.homeTitle.tr(context),
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        page: const HomePage(),
        priority: 10,
        groupId: 'general',
        defaultEnabled: true,
      ),
    );

    LocalizationService().registerModuleTranslations(homeTranslations);
  }
}
