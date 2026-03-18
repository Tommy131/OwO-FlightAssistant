import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/module_registry/sidebar/sidebar_mini_card.dart';
import '../../../core/theme/app_theme_data.dart';
import '../localization/home_localization_keys.dart';
import '../../flight_logs/providers/flight_logs_provider.dart';
import '../models/home_models.dart';
import '../providers/home_provider.dart';

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

class HomeDefaultSidebarMiniCard extends SidebarMiniCard {
  HomeDefaultSidebarMiniCard()
    : super(id: 'default_app_mini_card', priority: 1000);

  @override
  bool canDisplay(BuildContext context) {
    final home = context.watch<HomeProvider?>();
    return home == null || !home.isConnected;
  }

  @override
  Widget build(
    BuildContext context, {
    required ThemeData theme,
    required bool isCollapsed,
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

class HomeConnectedSidebarMiniCard extends SidebarMiniCard {
  HomeConnectedSidebarMiniCard()
    : super(id: 'connected_flight_mini_card', priority: 10);

  @override
  bool canDisplay(BuildContext context) {
    final home = context.watch<HomeProvider?>();
    return home != null && home.isConnected;
  }

  @override
  Widget build(
    BuildContext context, {
    required ThemeData theme,
    required bool isCollapsed,
  }) {
    final home = context.watch<HomeProvider?>();
    if (home == null) {
      return const SizedBox.shrink();
    }

    final isRecording = context.watch<FlightLogsProvider>().isRecording;
    final info = _SidebarMiniStageResolver.buildStageInfo(context, home);

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
                Positioned(
                  right: -7,
                  top: -6,
                  child: _BlinkingBuilder(
                    /// 功能：执行builder的核心业务流程。
                    /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                    builder: (pulse) => _RecordingDot(pulse: pulse),
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
                  _BlinkingBuilder(
                    /// 功能：执行builder的核心业务流程。
                    /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
                    builder: (pulse) => _RecordingBadge(
                      pulse: pulse,
                      label: HomeLocalizationKeys.miniRecording.tr(context),
                      theme: theme,
                    ),
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

class _RecordingDot extends StatelessWidget {
  final double pulse;

  const _RecordingDot({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.redAccent.withValues(alpha: 0.3 + 0.7 * pulse),
      ),
    );
  }
}

class _RecordingBadge extends StatelessWidget {
  final double pulse;
  final String label;
  final ThemeData theme;

  const _RecordingBadge({
    required this.pulse,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1 + 0.2 * pulse),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.45 + 0.4 * pulse),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RecordingDot(pulse: pulse),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.redAccent.withValues(alpha: 0.6 + 0.4 * pulse),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingBuilder extends StatefulWidget {
  final Widget Function(double pulse) builder;

  const _BlinkingBuilder({required this.builder});

  @override
  State<_BlinkingBuilder> createState() => _BlinkingBuilderState();
}

class _BlinkingBuilderState extends State<_BlinkingBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      /// 功能：执行builder的核心业务流程。
      /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
      builder: (context, _) => widget.builder(_controller.value),
    );
  }
}

class _SidebarMiniStageResolver {
  static _MiniStageInfo buildStageInfo(
    BuildContext context,
    HomeProvider home,
  ) {
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
        weather = _weatherSummary(context, home.metarsByIcao[currentIcao]);
      }
      visibility = _visibilityLabel(data.visibility);
    }

    double? distanceNm;
    var distanceTarget = HomeLocalizationKeys.miniNearbyAirport.tr(context);
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
        distanceTarget = destination != null
            ? HomeLocalizationKeys.navDestination.tr(context)
            : HomeLocalizationKeys.miniNearbyAirport.tr(context);
      }
    }

    final eta = _etaLabel(distanceNm, data.groundSpeed);
    final distanceText = distanceNm == null
        ? '--'
        : '${distanceNm.toStringAsFixed(0)}nm';

    final stageName = switch (stage) {
      _MiniFlightStage.ground => HomeLocalizationKeys.miniStageGround.tr(
        context,
      ),
      _MiniFlightStage.climb => HomeLocalizationKeys.miniStageClimb.tr(
        context,
      ),
      _MiniFlightStage.cruise => HomeLocalizationKeys.miniStageCruise.tr(
        context,
      ),
      _MiniFlightStage.descent => HomeLocalizationKeys.miniStageDescent.tr(
        context,
      ),
      _MiniFlightStage.approach => HomeLocalizationKeys.miniStageApproach.tr(
        context,
      ),
    };

    final nearbyIcao = nearest?.icaoCode.isNotEmpty == true
        ? nearest!.icaoCode
        : '--';
    final currentIcao = nearbyIcao;
    final tooltip = switch (stage) {
      _MiniFlightStage.ground =>
        /// 功能：执行tr的核心业务流程。
        /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
        '${HomeLocalizationKeys.miniLabelPhase.tr(context)}: $stageName\n${HomeLocalizationKeys.miniLabelAirport.tr(context)}: $currentIcao\n${HomeLocalizationKeys.miniLabelWeather.tr(context)}: $weather\n${HomeLocalizationKeys.miniLabelVisibility.tr(context)}: $visibility',
      _MiniFlightStage.approach =>
        /// 功能：执行tr的核心业务流程。
        /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
        '${HomeLocalizationKeys.miniLabelPhase.tr(context)}: $stageName\n${HomeLocalizationKeys.miniLabelCurrentAirport.tr(context)}: $currentIcao\n${HomeLocalizationKeys.miniLabelWeather.tr(context)}: $weather',
      _MiniFlightStage.climb ||
      _MiniFlightStage.cruise ||
      _MiniFlightStage.descent =>
        /// 功能：执行tr的核心业务流程。
        /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
        '${HomeLocalizationKeys.miniLabelPhase.tr(context)}: $stageName\n${HomeLocalizationKeys.miniLabelNearbyAirport.tr(context)}: $nearbyIcao\n$distanceTarget ${HomeLocalizationKeys.miniLabelDistance.tr(context)}: $distanceText\n${HomeLocalizationKeys.miniLabelEta.tr(context)}: $eta',
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

  /// 功能：执行_resolveStage的核心业务流程。
  /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
  static _MiniFlightStage _resolveStage(HomeFlightData data) {
    final phase = (data.flightPhase ?? '').trim().toLowerCase();
    switch (phase) {
      case 'ground':
      case 'parked':
      case 'standby':
      case 'taxi':
        return _MiniFlightStage.ground;
      case 'takeoff':
      case 'climb':
        return _MiniFlightStage.climb;
      case 'cruise':
        return _MiniFlightStage.cruise;
      case 'descent':
        return _MiniFlightStage.descent;
      case 'approach':
      case 'landing':
        return _MiniFlightStage.approach;
      default:
        return _MiniFlightStage.cruise;
    }
  }

  /// 功能：执行_weatherSummary的核心业务流程。
  /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
  static String _weatherSummary(BuildContext context, HomeMetarData? metar) {
    if (metar == null) {
      return HomeLocalizationKeys.miniWeatherUnknown.tr(context);
    }
    final source = '${metar.raw} ${metar.displayWind}'.toUpperCase();
    if (source.contains('TS') || source.contains('雷暴')) {
      return HomeLocalizationKeys.miniWeatherThunderstorm.tr(context);
    }
    if (source.contains('+RA') || source.contains('暴雨')) {
      return HomeLocalizationKeys.miniWeatherHeavyRain.tr(context);
    }
    if (source.contains('RA') ||
        source.contains('DZ') ||
        source.contains('SH') ||
        source.contains('阴雨') ||
        /// 功能：执行contains的核心业务流程。
        /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
        source.contains('小雨')) {
      return HomeLocalizationKeys.miniWeatherRain.tr(context);
    }
    if (source.contains('SN') || source.contains('雪')) {
      return HomeLocalizationKeys.miniWeatherSnow.tr(context);
    }
    if (source.contains('FG') ||
        source.contains('BR') ||
        source.contains('HZ') ||
        /// 功能：执行contains的核心业务流程。
        /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
        source.contains('雾')) {
      return HomeLocalizationKeys.miniWeatherLowVisibility.tr(context);
    }
    if (source.contains('OVC') ||
        source.contains('BKN') ||
        /// 功能：执行contains的核心业务流程。
        /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
        source.contains('阴')) {
      return HomeLocalizationKeys.miniWeatherOvercast.tr(context);
    }
    if (source.contains('CAVOK') ||
        source.contains('SKC') ||
        source.contains('CLR') ||
        source.contains('FEW') ||
        source.contains('SCT') ||
        /// 功能：执行contains的核心业务流程。
        /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
        source.contains('晴')) {
      return HomeLocalizationKeys.miniWeatherExcellent.tr(context);
    }
    return HomeLocalizationKeys.miniWeatherNormal.tr(context);
  }

  /// 功能：执行_visibilityLabel的核心业务流程。
  /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
  static String _visibilityLabel(double? visibilityMeter) {
    if (visibilityMeter == null) return '--';
    if (visibilityMeter >= 10000) return '>10km';
    if (visibilityMeter >= 1000) {
      return '${(visibilityMeter / 1000).toStringAsFixed(1)}km';
    }
    return '${visibilityMeter.toStringAsFixed(0)}m';
  }

  /// 功能：执行_etaLabel的核心业务流程。
  /// 说明：该方法封装单一职责逻辑，便于后续维护、定位问题与扩展功能。
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
