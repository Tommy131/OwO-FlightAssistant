import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_group.dart';
import '../../core/module_registry/update/update_config.dart';
import '../../core/services/localization_service.dart';
import 'localization/common_localization.dart';
import 'localization/navigation_localization.dart';
import 'providers/flight_data_provider.dart';
import 'providers/middleware_flight_data_adapter.dart';
import 'sidebar/backend_status_sidebar_title_badge.dart';
import 'sidebar/sidebar_mini_cards.dart';

/// 公共模块注册器
///
/// 负责注册：
///   - 全局飞行数据 Provider（[FlightDataProvider]）
///   - 导航可用性规则（后端连通性校验）
///   - 侧边栏迷你卡片与标题徽章
///   - 导航分组与通用翻译
class CommonModule implements ModuleRegistrar {
  @override
  String get moduleName => 'common';

  @override
  void register() {
    final registry = ModuleRegistry();
    final adapter = MiddlewareFlightDataAdapter();

    // 适配器生命周期跟随模块
    registry.registerCleanup(() async {
      adapter.dispose();
    });

    // 注册全局飞行数据 Provider
    registry.providers.register(
      ChangeNotifierProvider(
        create: (_) => FlightDataProvider(adapter: adapter),
      ),
    );

    // 导航可用性：仅在后端可达时允许访问业务页面
    registry.navigationAvailability.register((context, item) {
      if (item.id == 'home' || item.id == 'settings') return true;
      final provider = context.watch<FlightDataProvider?>();
      return provider?.isBackendReachable ?? false;
    });

    // 侧边栏迷你卡片
    registry.sidebarMiniCards.register(
      'connected_flight_mini_card',
      () => HomeConnectedSidebarMiniCard(),
    );
    registry.sidebarMiniCards.register(
      'default_app_mini_card',
      () => HomeDefaultSidebarMiniCard(),
    );

    // 侧边栏标题与徽章
    registry.sidebarTitle.register(
      'home_sidebar_title',
      (context) => AppConstants.appName,
    );
    registry.sidebarTitleBadge.register(
      'home_backend_status_title_badge',
      () => HomeBackendStatusSidebarTitleBadge(),
    );

    // 注册全局通用文案（首页 + 导航分组）
    LocalizationService().registerModuleTranslations(commonModuleTranslations);
    LocalizationService().registerModuleTranslations(
      navigationModuleTranslations,
    );

    // 注册导航分组
    final navigation = ModuleRegistry().navigation;
    navigation.registerGroup(
      (context) => NavigationGroup(
        id: 'general',
        title: NavigationLocalizationKeys.navGroupGeneral.tr(context),
        icon: Icons.dashboard_outlined,
        priority: 0,
      ),
    );
    navigation.registerGroup(
      (context) => NavigationGroup(
        id: 'flight',
        title: NavigationLocalizationKeys.navGroupFlight.tr(context),
        icon: Icons.flight_takeoff_outlined,
        priority: 10,
      ),
    );
    navigation.registerGroup(
      (context) => NavigationGroup(
        id: 'tools',
        title: NavigationLocalizationKeys.navGroupTools.tr(context),
        icon: Icons.construction_outlined,
        priority: 20,
      ),
    );

    UpdateConfig.setCustomConfig(
      const UpdateConfig(
        versionCheckUrl:
            'https://api.github.com/repos/Tommy131/OwO-FlightAssistant/releases/latest',
        timeoutSeconds: 20,
      ),
    );
  }
}
