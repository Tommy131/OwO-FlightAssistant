import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/services/localization_service.dart';
import 'localization/briefing_localization_keys.dart';
import 'localization/briefing_translations.dart';
import 'pages/briefing_page.dart';
import 'providers/briefing_provider.dart';

class BriefingModule implements ModuleRegistrar {
  @override
  String get moduleName => 'briefing';

  @override
  void register() {
    final registry = ModuleRegistry();
    LocalizationService().registerModuleTranslations(briefingTranslations);

    registry.providers.register(
      ChangeNotifierProvider(create: (_) => BriefingProvider()),
    );

    registry.navigation.register(
      (context) => NavigationItem(
        id: 'briefing',
        title: BriefingLocalizationKeys.navTitle.tr(context),
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment,
        page: const BriefingPage(),
        priority: 15,
        groupId: 'flight',
      ),
    );
  }
}
