import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/services/localization_service.dart';
import 'localization/checklist_localization_keys.dart';
import 'localization/checklist_translations.dart';
import 'pages/checklist_page.dart';
import 'providers/checklist_provider.dart';

class ChecklistModule implements ModuleRegistrar {
  @override
  String get moduleName => 'checklist';

  @override
  void register() {
    final registry = ModuleRegistry();
    LocalizationService().registerModuleTranslations(checklistTranslations);

    registry.providers.register(
      ChangeNotifierProvider(create: (_) => ChecklistProvider()),
    );

    registry.navigation.register(
      (context) => NavigationItem(
        id: 'checklist',
        title: ChecklistLocalizationKeys.navTitle.tr(context),
        icon: Icons.checklist_outlined,
        activeIcon: Icons.checklist,
        page: const ChecklistPage(),
        priority: 20,
      ),
    );
  }
}
