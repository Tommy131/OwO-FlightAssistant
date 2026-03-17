import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../core/constants/app_constants.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/module_registry/sidebar/sidebar_mini_card.dart';
import '../../core/services/localization_service.dart';
import '../../core/theme/app_theme_data.dart';
import '../flight_logs/providers/flight_logs_provider.dart';
import 'localization/common_localization_keys.dart';
import 'localization/common_translations.dart';
import 'models/home_models.dart';
import 'pages/home_page.dart';
import 'providers/home_provider.dart';

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
      () => _CommonConnectedSidebarMiniCard(),
    );
    registry.sidebarMiniCards.register(
      'default_app_mini_card',
      () => _CommonDefaultSidebarMiniCard(),
    );
  }
}

enum _MiniFlightStage { ground, climb, cruise, descent, approach }

class _MiniStageInfo {
  final _MiniFlightStage stage;
  final String stageName;
  final String line2;
  final String tooltip;

  const _MiniStageInfo({
    required this.stage,
    required this.stageName,
    required this.line2,
    required this.tooltip,
  });
}

class _CommonDefaultSidebarMiniCard extends SidebarMiniCard {
  _CommonDefaultSidebarMiniCard()
    : super(id: 'default_app_mini_card', priority: 1000);

  @override
  bool canDisplay(HomeProvider? home) => home == null || !home.isConnected;

  @override
  Widget build(
    BuildContext context, {
    required ThemeData theme,
    required bool isCollapsed,
    required HomeProvider? home,
  }) {
    if (isCollapsed) {
      return Tooltip(
        key: const ValueKey('mini_info_collapsed'),
        message: '${AppConstants.appName} ${AppConstants.appVersion}',
        child: _MiniCardContainer(
          theme: theme,
          isCollapsed: true,
          child: Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    return _MiniCardContainer(
      key: const ValueKey('mini_info_expanded'),
      theme: theme,
      isCollapsed: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppConstants.appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'v${AppConstants.appVersion}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommonConnectedSidebarMiniCard extends SidebarMiniCard {
  _CommonConnectedSidebarMiniCard()
    : super(id: 'connected_flight_mini_card', priority: 10);

  @override
  bool canDisplay(HomeProvider? home) => home != null && home.isConnected;

  @override
  Widget build(
    BuildContext context, {
    required ThemeData theme,
    required bool isCollapsed,
    required HomeProvider? home,
  }) {
    if (home == null) {
      return const SizedBox.shrink();
    }

    final isRecording = context.watch<FlightLogsProvider>().isRecording;
    final info = _SidebarMiniStageResolver.buildStageInfo(home);

    if (isCollapsed) {
      return Tooltip(
        key: const ValueKey('mini_info_connected_collapsed'),
        message: info.tooltip,
        child: _buildContainer(
          theme: theme,
          isCollapsed: true,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                switch (info.stage) {
                  _MiniFlightStage.ground => Icons.local_airport_rounded,
                  _MiniFlightStage.climb => Icons.trending_up_rounded,
                  _MiniFlightStage.cruise => Icons.flight_rounded,
                  _MiniFlightStage.descent => Icons.trending_down_rounded,
                  _MiniFlightStage.approach => Icons.flight_land_rounded,
                },
                size: 16,
                color: theme.colorScheme.primary,
              ),
              if (isRecording)
                const Positioned(
                  right: -7,
                  top: -6,
                  child: Icon(
                    Icons.fiber_manual_record_rounded,
                    size: 12,
                    color: Colors.redAccent,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Tooltip(
      key: const ValueKey('mini_info_connected_expanded'),
      message: info.tooltip,
      child: _buildContainer(
        theme: theme,
        isCollapsed: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    info.stageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isRecording)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fiber_manual_record_rounded,
                        size: 14,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'REC',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              info.line2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContainer({
    required ThemeData theme,
    required bool isCollapsed,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: isCollapsed
          ? const EdgeInsets.symmetric(vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: child,
    );
  }
}

class _MiniCardContainer extends StatelessWidget {
  final ThemeData theme;
  final bool isCollapsed;
  final Widget child;

  const _MiniCardContainer({
    super.key,
    required this.theme,
    required this.isCollapsed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: isCollapsed
          ? const EdgeInsets.symmetric(vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: child,
    );
  }
}

class _SidebarMiniStageResolver {
  static _MiniStageInfo buildStageInfo(HomeProvider home) {
    final data = home.flightData;
    final stage = _resolveStage(data);
    final nearest = home.nearestAirport;
    final destination = home.destinationAirport;
    final currentLat = data.latitude;
    final currentLon = data.longitude;

    String weather = '--';
    String visibility = '--';
    if (stage == _MiniFlightStage.ground ||
        stage == _MiniFlightStage.approach) {
      final currentIcao = nearest?.icaoCode;
      if (currentIcao != null && currentIcao.isNotEmpty) {
        weather = _weatherSummary(home.metarsByIcao[currentIcao]);
      }
      visibility = _visibilityLabel(data.visibility);
    }

    double? distanceNm;
    var distanceTarget = '附近机场';
    if (currentLat != null && currentLon != null) {
      final primaryTarget = destination ?? nearest;
      if (primaryTarget != null &&
          primaryTarget.latitude != 0 &&
          primaryTarget.longitude != 0) {
        distanceNm = _calculateDistanceNm(
          currentLat,
          currentLon,
          primaryTarget.latitude,
          primaryTarget.longitude,
        );
        distanceTarget = destination != null ? '目的地' : '附近机场';
      }
    }

    final eta = _etaLabel(distanceNm, data.groundSpeed);
    final distanceText = distanceNm == null
        ? '--'
        : '${distanceNm.toStringAsFixed(0)}nm';

    final stageName = switch (stage) {
      _MiniFlightStage.ground => '在地面',
      _MiniFlightStage.climb => '爬升中',
      _MiniFlightStage.cruise => '巡航中',
      _MiniFlightStage.descent => '下降中',
      _MiniFlightStage.approach => '进近中',
    };

    final nearbyIcao = nearest?.icaoCode.isNotEmpty == true
        ? nearest!.icaoCode
        : '--';
    final currentIcao = nearbyIcao;
    final tooltip = switch (stage) {
      _MiniFlightStage.ground =>
        '阶段: $stageName\n机场: $currentIcao\n天气: $weather\n能见度: $visibility',
      _MiniFlightStage.approach =>
        '阶段: $stageName\n当前机场: $currentIcao\n天气: $weather',
      _MiniFlightStage.climb ||
      _MiniFlightStage.cruise ||
      _MiniFlightStage.descent =>
        '阶段: $stageName\n附近机场: $nearbyIcao\n$distanceTarget距离: $distanceText\n预计到达: $eta',
    };

    final line2 = switch (stage) {
      _MiniFlightStage.ground => '$currentIcao · $weather',
      _MiniFlightStage.approach => '$currentIcao · $weather',
      _MiniFlightStage.climb ||
      _MiniFlightStage.cruise ||
      _MiniFlightStage.descent => '$nearbyIcao · $distanceText · $eta',
    };

    return _MiniStageInfo(
      stage: stage,
      stageName: stageName,
      line2: line2,
      tooltip: tooltip,
    );
  }

  static _MiniFlightStage _resolveStage(HomeFlightData data) {
    final altitude = data.altitude;
    final verticalSpeed = data.verticalSpeed;
    final groundSpeed = data.groundSpeed;
    if (data.onGround == true) return _MiniFlightStage.ground;
    final approachLike =
        (altitude ?? 0) <= 5000 &&
        (verticalSpeed ?? 0) <= -300 &&
        ((groundSpeed ?? 0) <= 220 ||
            data.gearDown == true ||
            data.flapsDeployed == true);
    if (approachLike) return _MiniFlightStage.approach;
    if ((verticalSpeed ?? 0) >= 300) return _MiniFlightStage.climb;
    if ((verticalSpeed ?? 0) <= -300) return _MiniFlightStage.descent;
    return _MiniFlightStage.cruise;
  }

  static String _weatherSummary(HomeMetarData? metar) {
    if (metar == null) return '未知';
    final source = '${metar.raw} ${metar.displayWind}'.toUpperCase();
    if (source.contains('TS') || source.contains('雷暴')) return '雷暴';
    if (source.contains('+RA') || source.contains('暴雨')) return '暴雨';
    if (source.contains('RA') ||
        source.contains('DZ') ||
        source.contains('SH') ||
        source.contains('阴雨') ||
        source.contains('小雨')) {
      return '阴雨';
    }
    if (source.contains('SN') || source.contains('雪')) return '降雪';
    if (source.contains('FG') ||
        source.contains('BR') ||
        source.contains('HZ') ||
        source.contains('雾')) {
      return '低能见';
    }
    if (source.contains('OVC') ||
        source.contains('BKN') ||
        source.contains('阴')) {
      return '阴天';
    }
    if (source.contains('CAVOK') ||
        source.contains('SKC') ||
        source.contains('CLR') ||
        source.contains('FEW') ||
        source.contains('SCT') ||
        source.contains('晴')) {
      return '天气极好';
    }
    return '天气一般';
  }

  static String _visibilityLabel(double? visibilityMeter) {
    if (visibilityMeter == null) return '--';
    if (visibilityMeter >= 10000) return '>10km';
    if (visibilityMeter >= 1000) {
      return '${(visibilityMeter / 1000).toStringAsFixed(1)}km';
    }
    return '${visibilityMeter.toStringAsFixed(0)}m';
  }

  static String _etaLabel(double? distanceNm, double? groundSpeed) {
    if (distanceNm == null || groundSpeed == null || groundSpeed <= 30) {
      return '--';
    }
    final hours = distanceNm / groundSpeed;
    final eta = DateTime.now().add(Duration(minutes: (hours * 60).round()));
    final hh = eta.hour.toString().padLeft(2, '0');
    final mm = eta.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  static double _calculateDistanceNm(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) {
    const earthRadiusKm = 6371.0;
    final lat1 = startLat * 0.017453292519943295;
    final lon1 = startLon * 0.017453292519943295;
    final lat2 = endLat * 0.017453292519943295;
    final lon2 = endLon * 0.017453292519943295;
    final deltaLat = lat2 - lat1;
    final deltaLon = lon2 - lon1;
    final a =
        (math.sin(deltaLat / 2) * math.sin(deltaLat / 2)) +
        (math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final km = earthRadiusKm * c;
    return km * 0.539956803;
  }
}
