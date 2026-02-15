import 'package:flutter/material.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/services/localization_service.dart';
import 'localization/toolbox_localization_keys.dart';
import 'localization/toolbox_translations.dart';
import 'pages/toolbox_page.dart';

class ToolboxModule implements ModuleRegistrar {
  @override
  String get moduleName => 'toolbox';

  @override
  void register() {
    final registry = ModuleRegistry();
    LocalizationService().registerModuleTranslations(toolboxTranslations);

    registry.navigation.register(
      (context) => NavigationItem(
        id: 'toolbox',
        title: ToolboxLocalizationKeys.toolboxTitle.tr(context),
        icon: Icons.build_outlined,
        activeIcon: Icons.build,
        page: const ToolboxPage(),
        priority: 35,
      ),
    );
  }
}
