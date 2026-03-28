import 'package:flutter/material.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/services/localization_service.dart';
import 'localization/log_viewer_localization_keys.dart';
import 'localization/log_viewer_translations.dart';
import 'pages/log_viewer_page.dart';

class LogViewerModule implements ModuleRegistrar {
  @override
  String get moduleName => 'log_viewer';

  @override
  void register() {
    final registry = ModuleRegistry();

    // 注册模块翻译
    LocalizationService().registerModuleTranslations(logViewerTranslations);

    // 注册导航项（工具分组，优先级 100）
    registry.navigation.register(
      (context) => NavigationItem(
        id: 'log_viewer',
        title: LogViewerLocalizationKeys.navTitle.tr(context),
        icon: Icons.notes_outlined,
        activeIcon: Icons.notes,
        page: const LogViewerPage(),
        priority: 100,
        groupId: 'tools',
        defaultEnabled: true,
      ),
    );
  }
}
