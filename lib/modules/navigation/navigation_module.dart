import 'package:flutter/material.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_group.dart';
import '../../core/services/localization_service.dart';

class NavigationModuleLocalizationKeys {
  static const String navGroupGeneral = 'navigation.group.general';
  static const String navGroupFlight = 'navigation.group.flight';
  static const String navGroupTools = 'navigation.group.tools';
  static const String navGroupOthers = 'navigation.group.others';
}

final Map<String, Map<String, String>> navigationModuleTranslations = {
  'zh_CN': {
    NavigationModuleLocalizationKeys.navGroupGeneral: '概览',
    NavigationModuleLocalizationKeys.navGroupFlight: '飞行',
    NavigationModuleLocalizationKeys.navGroupTools: '工具',
    NavigationModuleLocalizationKeys.navGroupOthers: '其他',
  },
  'en_US': {
    NavigationModuleLocalizationKeys.navGroupGeneral: 'GENERAL',
    NavigationModuleLocalizationKeys.navGroupFlight: 'FLIGHT',
    NavigationModuleLocalizationKeys.navGroupTools: 'TOOLS',
    NavigationModuleLocalizationKeys.navGroupOthers: 'OTHERS',
  },
};

class NavigationModule implements ModuleRegistrar {
  @override
  String get moduleName => 'navigation';

  @override
  void register() {
    LocalizationService().registerModuleTranslations(
      navigationModuleTranslations,
    );
    final navigation = ModuleRegistry().navigation;

    navigation.registerGroup(
      (context) => NavigationGroup(
        id: 'general',
        title: NavigationModuleLocalizationKeys.navGroupGeneral.tr(context),
        icon: Icons.dashboard_outlined,
        priority: 0,
      ),
    );
    navigation.registerGroup(
      (context) => NavigationGroup(
        id: 'flight',
        title: NavigationModuleLocalizationKeys.navGroupFlight.tr(context),
        icon: Icons.flight_takeoff_outlined,
        priority: 10,
      ),
    );
    navigation.registerGroup(
      (context) => NavigationGroup(
        id: 'tools',
        title: NavigationModuleLocalizationKeys.navGroupTools.tr(context),
        icon: Icons.construction_outlined,
        priority: 20,
      ),
    );
  }
}
