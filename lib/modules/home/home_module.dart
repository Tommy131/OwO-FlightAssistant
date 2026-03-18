import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/services/localization_service.dart';
import 'localization/home_localization_keys.dart';
import 'localization/home_translations.dart';
import 'pages/home_page.dart';
import 'providers/home_provider.dart';
import 'sidebar/backend_status_sidebar_title_badge.dart';
import 'sidebar/sidebar_mini_cards.dart';

class HomeModule implements ModuleRegistrar {
  @override
  String get moduleName => 'home';

  @override
  void register() {
    final registry = ModuleRegistry();
    LocalizationService().registerModuleTranslations(homeTranslations);
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
        title: HomeLocalizationKeys.homeTitle.tr(context),
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        page: const HomePage(),
        priority: 10,
        groupId: 'general',
      ),
    );

    registry.sidebarMiniCards.register(
      'connected_flight_mini_card',
      () => HomeConnectedSidebarMiniCard(),
    );
    registry.sidebarMiniCards.register(
      'default_app_mini_card',
      () => HomeDefaultSidebarMiniCard(),
    );
    registry.sidebarTitle.register(
      'home_sidebar_title',
      (context) => AppConstants.appName,
    );
    registry.sidebarTitleBadge.register(
      'home_backend_status_title_badge',
      () => HomeBackendStatusSidebarTitleBadge(),
    );
  }
}
