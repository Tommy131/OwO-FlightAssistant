import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/services/localization_service.dart';
import '../common/providers/common_provider.dart';
import 'localization/monitor_localization_keys.dart';
import 'localization/monitor_translations.dart';
import 'pages/monitor_page.dart';
import 'providers/monitor_provider.dart';

/// 监控模块注册器
///
/// 实现 [ModuleRegistrar] 接口，在应用启动时向核心框架注册以下内容：
/// 1. 本地化翻译：将 [monitorTranslations] 注入 [LocalizationService]
/// 2. 状态管理：注册 [MonitorProvider]，并通过 [ChangeNotifierProxyProvider]
///    监听 [HomeProvider] 的数据变化，自动同步飞行数据快照
/// 3. 导航项：以优先级 30 注册到 'flight' 导航分组
class MonitorModule implements ModuleRegistrar {
  @override
  String get moduleName => 'monitor';

  @override
  void register() {
    final registry = ModuleRegistry();

    // 注册模块翻译（支持 zh_CN / en_US）
    LocalizationService().registerModuleTranslations(monitorTranslations);

    // 注册 MonitorProvider（依赖 HomeProvider，通过代理 Provider 桥接数据）
    registry.providers.register(
      ChangeNotifierProxyProvider<HomeProvider, MonitorProvider>(
        create: (_) => MonitorProvider(),
        update: (_, homeProvider, monitorProvider) {
          final provider = monitorProvider ?? MonitorProvider();
          // 每当 HomeProvider 数据更新时，同步最新的飞行数据快照
          provider.updateFromHomeSnapshot(homeProvider.snapshot);
          return provider;
        },
      ),
    );

    // 注册导航项（飞行分组，优先级 30）
    registry.navigation.register(
      (context) => NavigationItem(
        id: 'monitor',
        title: MonitorLocalizationKeys.navTitle.tr(context),
        icon: Icons.monitor_heart_outlined,
        activeIcon: Icons.monitor_heart,
        page: const MonitorPage(),
        priority: 30,
        groupId: 'flight',
      ),
    );
  }
}
