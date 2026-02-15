import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/services/localization_service.dart';
import 'localization/monitor_localization_keys.dart';
import 'localization/monitor_translations.dart';
import 'pages/monitor_page.dart';
import 'providers/monitor_provider.dart';

class MonitorModule implements ModuleRegistrar {
  @override
  String get moduleName => 'monitor';

  @override
  void register() {
    final registry = ModuleRegistry();
    LocalizationService().registerModuleTranslations(monitorTranslations);

    registry.providers.register(
      ChangeNotifierProvider(create: (_) => MonitorProvider()),
    );

    registry.navigation.register(
      (context) => NavigationItem(
        id: 'monitor',
        title: MonitorLocalizationKeys.navTitle.tr(context),
        icon: Icons.monitor_heart_outlined,
        activeIcon: Icons.monitor_heart,
        page: const MonitorPage(),
        priority: 30,
      ),
    );
  }
}
