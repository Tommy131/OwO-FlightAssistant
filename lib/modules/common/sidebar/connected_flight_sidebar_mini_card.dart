import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/module_registry/sidebar/sidebar_mini_card.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../localization/common_localization.dart';
import '../../flight_logs/providers/flight_logs_provider.dart';
import '../models/common_models.dart';
import '../providers/flight_data_provider.dart';

/// 已连接模拟器时显示的飞行状态迷你卡片
///
/// 展示当前飞行阶段（地面/爬升/巡航/下降/进近）、天气、
/// 目的地或最近机场距离、预计到达时间，以及飞行记录指示器。
class HomeConnectedSidebarMiniCard extends SidebarMiniCard {
  HomeConnectedSidebarMiniCard()
    : super(id: 'connected_flight_mini_card', priority: 10);

  @override
  bool canDisplay(BuildContext context) {
    final provider = context.watch<FlightDataProvider?>();
    return provider != null && provider.isConnected;
  }

  @override
  Widget build(
    BuildContext context, {
    required ThemeData theme,
    required bool isCollapsed,
  }) {
    final provider = context.watch<FlightDataProvider?>();
    if (provider == null) return const SizedBox.shrink();

    final isRecording = context.watch<FlightLogsProvider>().isRecording;
    final info = _FlightStageResolver.buildStageInfo(context, provider);

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
                  _FlightStage.ground => Icons.local_airport_rounded,
                  _FlightStage.climb => Icons.trending_up_rounded,
                  _FlightStage.cruise => Icons.flight_rounded,
                  _FlightStage.descent => Icons.trending_down_rounded,
                  _FlightStage.approach => Icons.flight_land_rounded,
                },
                size: 16,
                color: theme.colorScheme.primary,
              ),
              if (isRecording)
                Positioned(
                  right: -7,
                  top: -6,
                  child: _BlinkingBuilder(
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
                    builder: (pulse) => _RecordingBadge(
                      pulse: pulse,
                      label: CommonLocalizationKeys.miniRecording.tr(context),
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

// ──────────────────────────────────────────────────────────────────────────
// 内部枚举与辅助类
// ──────────────────────────────────────────────────────────────────────────

/// 侧边栏显示用的简化飞行阶段
enum _FlightStage { ground, climb, cruise, descent, approach }

class _StageInfo {
  final _FlightStage stage;
  final String stageName;
  final String line2;
  final String tooltip;

  const _StageInfo({
    required this.stage,
    required this.stageName,
    required this.line2,
    required this.tooltip,
  });
}

/// 飞行阶段信息解析器（从 [FlightData] 推导显示内容）
class _FlightStageResolver {
  static _StageInfo buildStageInfo(
    BuildContext context,
    FlightDataProvider provider,
  ) {
    final data = provider.flightData;
    final stage = _resolveStage(data);
    final nearest = provider.nearestAirport;
    final destination = provider.destinationAirport;
    final currentLat = data.latitude;
    final currentLon = data.longitude;

    String weather = '--';
    String visibility = '--';
    if (stage == _FlightStage.ground || stage == _FlightStage.approach) {
      final currentIcao = nearest?.icaoCode;
      if (currentIcao != null && currentIcao.isNotEmpty) {
        weather = _weatherSummary(context, provider.metarsByIcao[currentIcao]);
      }
      visibility = _visibilityLabel(data.visibility);
    }

    double? distanceNm;
    var distanceTarget = CommonLocalizationKeys.miniNearbyAirport.tr(context);
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
            ? CommonLocalizationKeys.navDestination.tr(context)
            : CommonLocalizationKeys.miniNearbyAirport.tr(context);
      }
    }

    final eta = _etaLabel(distanceNm, data.groundSpeed);
    final distanceText = distanceNm == null
        ? '--'
        : '${distanceNm.toStringAsFixed(0)}nm';

    final stageName = switch (stage) {
      _FlightStage.ground => CommonLocalizationKeys.miniStageGround.tr(context),
      _FlightStage.climb => CommonLocalizationKeys.miniStageClimb.tr(context),
      _FlightStage.cruise => CommonLocalizationKeys.miniStageCruise.tr(context),
      _FlightStage.descent => CommonLocalizationKeys.miniStageDescent.tr(
        context,
      ),
      _FlightStage.approach => CommonLocalizationKeys.miniStageApproach.tr(
        context,
      ),
    };

    final nearbyIcao = nearest?.icaoCode.isNotEmpty == true
        ? nearest!.icaoCode
        : '--';
    final tooltip = switch (stage) {
      _FlightStage.ground =>
        '${CommonLocalizationKeys.miniLabelPhase.tr(context)}: $stageName\n'
            '${CommonLocalizationKeys.miniLabelAirport.tr(context)}: $nearbyIcao\n'
            '${CommonLocalizationKeys.miniLabelWeather.tr(context)}: $weather\n'
            '${CommonLocalizationKeys.miniLabelVisibility.tr(context)}: $visibility',
      _FlightStage.approach =>
        '${CommonLocalizationKeys.miniLabelPhase.tr(context)}: $stageName\n'
            '${CommonLocalizationKeys.miniLabelCurrentAirport.tr(context)}: $nearbyIcao\n'
            '${CommonLocalizationKeys.miniLabelWeather.tr(context)}: $weather',
      _FlightStage.climb || _FlightStage.cruise || _FlightStage.descent =>
        '${CommonLocalizationKeys.miniLabelPhase.tr(context)}: $stageName\n'
            '${CommonLocalizationKeys.miniLabelNearbyAirport.tr(context)}: $nearbyIcao\n'
            '$distanceTarget ${CommonLocalizationKeys.miniLabelDistance.tr(context)}: $distanceText\n'
            '${CommonLocalizationKeys.miniLabelEta.tr(context)}: $eta',
    };

    final line2 = switch (stage) {
      _FlightStage.ground => '$nearbyIcao · $weather',
      _FlightStage.approach => '$nearbyIcao · $weather',
      _FlightStage.climb ||
      _FlightStage.cruise ||
      _FlightStage.descent => '$nearbyIcao · $distanceText · $eta',
    };

    return _StageInfo(
      stage: stage,
      stageName: stageName,
      line2: line2,
      tooltip: tooltip,
    );
  }

  static _FlightStage _resolveStage(FlightData data) {
    final phase = (data.flightPhase ?? '').trim().toLowerCase();
    return switch (phase) {
      'ground' || 'parked' || 'standby' || 'taxi' => _FlightStage.ground,
      'takeoff' || 'climb' => _FlightStage.climb,
      'cruise' => _FlightStage.cruise,
      'descent' => _FlightStage.descent,
      'approach' || 'landing' => _FlightStage.approach,
      _ => _FlightStage.cruise,
    };
  }

  static String _weatherSummary(BuildContext context, LiveMetarData? metar) {
    if (metar == null) {
      return CommonLocalizationKeys.miniWeatherUnknown.tr(context);
    }
    final source = '${metar.raw} ${metar.displayWind}'.toUpperCase();
    if (source.contains('TS') || source.contains('雷暴')) {
      return CommonLocalizationKeys.miniWeatherThunderstorm.tr(context);
    }
    if (source.contains('+RA') || source.contains('暴雨')) {
      return CommonLocalizationKeys.miniWeatherHeavyRain.tr(context);
    }
    if (source.contains('RA') ||
        source.contains('DZ') ||
        source.contains('SH') ||
        source.contains('阴雨') ||
        source.contains('小雨')) {
      return CommonLocalizationKeys.miniWeatherRain.tr(context);
    }
    if (source.contains('SN') || source.contains('雪')) {
      return CommonLocalizationKeys.miniWeatherSnow.tr(context);
    }
    if (source.contains('FG') ||
        source.contains('BR') ||
        source.contains('HZ') ||
        source.contains('雾')) {
      return CommonLocalizationKeys.miniWeatherLowVisibility.tr(context);
    }
    if (source.contains('OVC') ||
        source.contains('BKN') ||
        source.contains('阴')) {
      return CommonLocalizationKeys.miniWeatherOvercast.tr(context);
    }
    if (source.contains('CAVOK') ||
        source.contains('SKC') ||
        source.contains('CLR') ||
        source.contains('FEW') ||
        source.contains('SCT') ||
        source.contains('晴')) {
      return CommonLocalizationKeys.miniWeatherExcellent.tr(context);
    }
    return CommonLocalizationKeys.miniWeatherNormal.tr(context);
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
    return earthRadiusKm * c * 0.539956803;
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 录制指示相关小部件
// ──────────────────────────────────────────────────────────────────────────

/// 录制中闪烁圆点
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

/// 录制中闪烁徽章（展开状态）
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

/// 闪烁动画驱动器（基于 AnimationController 的 Builder widget）
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
      builder: (context, _) => widget.builder(_controller.value),
    );
  }
}
