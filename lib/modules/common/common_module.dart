import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/services/localization_service.dart';
import 'localization/common_localization_keys.dart';
import 'localization/common_translations.dart';
import 'pages/home_page.dart';
import 'providers/home_provider.dart';

class CommonModule implements ModuleRegistrar {
  @override
  String get moduleName => 'common';

  @override
  void register() {
    final registry = ModuleRegistry();
    LocalizationService().registerModuleTranslations(commonTranslations);

    registry.providers.register(
      ChangeNotifierProvider(create: (_) => HomeProvider()),
    );

    registry.navigation.register(
      (context) => NavigationItem(
        id: 'home',
        title: CommonLocalizationKeys.homeTitle.tr(context),
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        page: const HomePage(),
        priority: 10,
      ),
    );
  }
}
