import 'package:flutter/material.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/app_bar/app_bar_action.dart';
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
        groupId: 'tools',
      ),
    );

    registry.appBarActions.registerSideMenu(
      'toolbox_side_menu_unit',
      () => AppBarSideMenuEntry(
        id: 'toolbox_side_menu_unit',
        navigationId: 'toolbox',
        icon: Icons.calculate_outlined,
        titleBuilder: (context) => ToolboxLocalizationKeys.unitTab.tr(context),
        priority: 10,
        stateListenable: ToolboxSectionController.instance,
        isSelected: (_) =>
            ToolboxSectionController.instance.selectedSection ==
            ToolboxSection.unitConversion,
        onTap: (_) {
          ToolboxSectionController.instance.select(
            ToolboxSection.unitConversion,
          );
        },
      ),
    );

    registry.appBarActions.registerSideMenu(
      'toolbox_side_menu_terms',
      () => AppBarSideMenuEntry(
        id: 'toolbox_side_menu_terms',
        navigationId: 'toolbox',
        icon: Icons.translate_outlined,
        titleBuilder: (context) => ToolboxLocalizationKeys.termsTab.tr(context),
        priority: 20,
        stateListenable: ToolboxSectionController.instance,
        isSelected: (_) =>
            ToolboxSectionController.instance.selectedSection ==
            ToolboxSection.termTranslation,
        onTap: (_) {
          ToolboxSectionController.instance.select(
            ToolboxSection.termTranslation,
          );
        },
      ),
    );

    registry.appBarActions.registerSideMenu(
      'toolbox_side_menu_calculators',
      () => AppBarSideMenuEntry(
        id: 'toolbox_side_menu_calculators',
        navigationId: 'toolbox',
        icon: Icons.flight_takeoff_outlined,
        titleBuilder: (context) =>
            ToolboxLocalizationKeys.calculatorsTab.tr(context),
        priority: 30,
        stateListenable: ToolboxSectionController.instance,
        isSelected: (_) =>
            ToolboxSectionController.instance.selectedSection ==
            ToolboxSection.flightCalculators,
        onTap: (_) {
          ToolboxSectionController.instance.select(
            ToolboxSection.flightCalculators,
          );
        },
      ),
    );

    registry.appBarActions.registerSideMenu(
      'toolbox_side_menu_weather',
      () => AppBarSideMenuEntry(
        id: 'toolbox_side_menu_weather',
        navigationId: 'toolbox',
        icon: Icons.cloud_outlined,
        titleBuilder: (context) =>
            ToolboxLocalizationKeys.weatherTab.tr(context),
        priority: 40,
        stateListenable: ToolboxSectionController.instance,
        isSelected: (_) =>
            ToolboxSectionController.instance.selectedSection ==
            ToolboxSection.weatherDecode,
        onTap: (_) {
          ToolboxSectionController.instance.select(
            ToolboxSection.weatherDecode,
          );
        },
      ),
    );

    registry.appBarActions.registerSideMenu(
      'toolbox_side_menu_performance',
      () => AppBarSideMenuEntry(
        id: 'toolbox_side_menu_performance',
        navigationId: 'toolbox',
        icon: Icons.speed_outlined,
        titleBuilder: (context) =>
            ToolboxLocalizationKeys.performanceTab.tr(context),
        priority: 50,
        stateListenable: ToolboxSectionController.instance,
        isSelected: (_) =>
            ToolboxSectionController.instance.selectedSection ==
            ToolboxSection.performanceTools,
        onTap: (_) {
          ToolboxSectionController.instance.select(
            ToolboxSection.performanceTools,
          );
        },
      ),
    );

    registry.appBarActions.registerSideMenu(
      'toolbox_side_menu_ops',
      () => AppBarSideMenuEntry(
        id: 'toolbox_side_menu_ops',
        navigationId: 'toolbox',
        icon: Icons.warning_amber_outlined,
        titleBuilder: (context) => ToolboxLocalizationKeys.opsTab.tr(context),
        priority: 60,
        stateListenable: ToolboxSectionController.instance,
        isSelected: (_) =>
            ToolboxSectionController.instance.selectedSection ==
            ToolboxSection.opsTools,
        onTap: (_) {
          ToolboxSectionController.instance.select(ToolboxSection.opsTools);
        },
      ),
    );
  }
}
