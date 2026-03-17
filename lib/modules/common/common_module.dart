import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/services/localization_service.dart';
import 'localization/common_localization_keys.dart';
import 'localization/common_translations.dart';
import 'pages/home_page.dart';
import 'providers/home_provider.dart';
import 'sidebar/backend_status_sidebar_title_badge.dart';
import 'sidebar/sidebar_mini_cards.dart';

class CommonModule implements ModuleRegistrar {
  @override
  String get moduleName => 'common';

  @override
  void register() {
    final registry = ModuleRegistry();
    LocalizationService().registerModuleTranslations(commonTranslations);
    final adapter = MiddlewareHomeDataAdapter();
    registry.registerCleanup(() async {
      adapter.dispose();
    });

    registry.providers.register(
      ChangeNotifierProvider(create: (_) => HomeProvider(adapter: adapter)),
    );

    registry.navigationAvailability.register((context, item) {
      if (item.id == 'home' || item.id == 'settings') {
        return true;
      }
      final home = context.watch<HomeProvider?>();
      return home?.isBackendReachable ?? false;
    });

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

    registry.sidebarMiniCards.register(
      'connected_flight_mini_card',
      () => CommonConnectedSidebarMiniCard(),
    );
    registry.sidebarMiniCards.register(
      'default_app_mini_card',
      () => CommonDefaultSidebarMiniCard(),
    );
    registry.sidebarTitle.register(
      'common_sidebar_title',
      (context) => AppConstants.appName,
    );
    registry.sidebarTitleBadge.register(
      'common_backend_status_title_badge',
      () => CommonBackendStatusSidebarTitleBadge(),
    );
  }
}
