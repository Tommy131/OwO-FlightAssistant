import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../constants/app_constants.dart';
import '../../theme/app_theme_data.dart';
import '../../module_registry/navigation/navigation_item.dart';
import '../../theme/theme_provider.dart';
import '../../localization/localization_keys.dart';
import '../../services/localization_service.dart';
import '../../module_registry/module_registry.dart';
import '../../module_registry/sidebar/sidebar_mini_card.dart';
import '../../../modules/common/models/home_models.dart';
import '../../../modules/common/providers/home_provider.dart';

/// 桌面端侧边栏组件（紧凑型）
/// 支持展开/折叠，带有流畅的动画过渡
class DesktopSidebar extends StatefulWidget {
  final List<NavigationItem> items;
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool initiallyExpanded;

  const DesktopSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.initiallyExpanded = true,
  });

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;
  late Animation<double> _fadeAnimation;

  // 提取常量，避免硬编码
  static const double _collapsedThreshold = 100.0;
  static const double _iconSize = 20.0;
  static const double _logoSize = 32.0;
  static const double _headerHeight = 56.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _registerDefaultMiniCards();
  }

  void _initializeAnimations() {
    _isExpanded = widget.initiallyExpanded;

    _animationController = AnimationController(
      duration: AppThemeData.animationDuration,
      vsync: this,
      value: _isExpanded ? 1.0 : 0.0,
    );

    final curvedAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _widthAnimation = Tween<double>(
      begin: AppThemeData.sidebarCollapsedWidth,
      end: AppThemeData.sidebarExpandedWidth,
    ).animate(curvedAnimation);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(curvedAnimation);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isExpanded = !_isExpanded;
      _isExpanded
          ? _animationController.forward()
          : _animationController.reverse();
    });
  }

  bool get _isCollapsed => _widthAnimation.value <= _collapsedThreshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          width: _widthAnimation.value,
          decoration: _buildContainerDecoration(theme),
          child: Column(
            children: [
              _buildHeader(theme),
              const SizedBox(height: AppThemeData.spacingSmall),
              _buildNavigationList(),
              _buildMiniInfoCard(theme),
              ...ModuleRegistry().sidebarFooters.getAllFooters().map(
                (footer) => _isCollapsed
                    ? footer.buildCollapsed(context)
                    : footer.buildExpanded(context),
              ),
            ],
          ),
        );
      },
    );
  }

  BoxDecoration _buildContainerDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.colorScheme.surface,
      border: Border(
        right: BorderSide(color: AppThemeData.getBorderColor(theme), width: 1),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      height: _headerHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: AppThemeData.spacingSmall,
      ),
      child: _isCollapsed
          ? _buildCollapsedHeader(theme)
          : _buildExpandedHeader(theme),
    );
  }

  Widget _buildCollapsedHeader(ThemeData theme) {
    return Center(
      child: Semantics(
        button: true,
        label: LocalizationKeys.expandSidebar.tr(context),
        child: Tooltip(
          message: LocalizationKeys.expandSidebar.tr(context),
          child: InkWell(
            onTap: _toggleSidebar,
            borderRadius: BorderRadius.circular(8),
            child: ExcludeSemantics(child: _buildLogo(theme)),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedHeader(ThemeData theme) {
    return Row(
      children: [
        _buildLogo(theme),
        const SizedBox(width: AppThemeData.spacingSmall),
        _buildLogoText(theme),
        _buildIconButton(
          icon: Icons.menu_open,
          tooltip: LocalizationKeys.collapseSidebar.tr(context),
          onPressed: _toggleSidebar,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildLogo(ThemeData theme) {
    return Container(
      width: _logoSize,
      height: _logoSize,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Semantics(
          image: true,
          label: LocalizationKeys.appLogo.tr(context),
          child: ExcludeSemantics(
            child: Image.asset(AppConstants.assetIconPath, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoText(ThemeData theme) {
    return Expanded(
      child: _buildFadeTransition(
        child: Text(
          LocalizationKeys.userGreeting.tr(context),
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: IconButton(
          icon: Icon(icon, color: theme.colorScheme.primary, size: _iconSize),
          onPressed: onPressed,
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: _logoSize,
            minHeight: _logoSize,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationList() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: AppThemeData.spacingSmall,
        ),
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          return _NavigationItemWidget(
            item: widget.items[index],
            index: index,
            isSelected: widget.selectedIndex == index,
            isCollapsed: _isCollapsed,
            fadeAnimation: _fadeAnimation,
            onTap: () => widget.onItemSelected(index),
          );
        },
      ),
    );
  }

  Widget _buildMiniInfoCard(ThemeData theme) {
    final home = Provider.of<HomeProvider?>(context);
    final card = ModuleRegistry().sidebarMiniCards.resolve(home);
    if (card == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppThemeData.spacingSmall,
        0,
        AppThemeData.spacingSmall,
        AppThemeData.spacingSmall,
      ),
      child: AnimatedSwitcher(
        duration: AppThemeData.animationDuration,
        child: KeyedSubtree(
          key: ValueKey(
            '${card.id}_${_isCollapsed ? 'collapsed' : 'expanded'}',
          ),
          child: card.build(
            context,
            theme: theme,
            isCollapsed: _isCollapsed,
            home: home,
          ),
        ),
      ),
    );
  }

  void _registerDefaultMiniCards() {
    final registry = ModuleRegistry().sidebarMiniCards;
    if (!registry.contains('connected_flight_mini_card')) {
      registry.register(
        'connected_flight_mini_card',
        () => _ConnectedSidebarMiniCard(),
      );
    }
    if (!registry.contains('default_app_mini_card')) {
      registry.register(
        'default_app_mini_card',
        () => _DefaultSidebarMiniCard(),
      );
    }
  }

  Widget _buildFadeTransition({required Widget child}) {
    return Opacity(opacity: _fadeAnimation.value, child: child);
  }
}

/// 导航项组件（提取为独立组件以提高复用性）
class _NavigationItemWidget extends StatelessWidget {
  final NavigationItem item;
  final int index;
  final bool isSelected;
  final bool isCollapsed;
  final Animation<double> fadeAnimation;
  final VoidCallback onTap;

  const _NavigationItemWidget({
    required this.item,
    required this.index,
    required this.isSelected,
    required this.isCollapsed,
    required this.fadeAnimation,
    required this.onTap,
  });

  static const double _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          container: true,
          button: true,
          selected: isSelected,
          label: _buildSemanticsLabel(context),
          onTap: onTap,
          enabled: true,
          focusable: true,
          child: ExcludeSemantics(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusSmall,
              ),
              child: AnimatedContainer(
                duration: AppThemeData.animationDuration,
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(
                  horizontal: isCollapsed ? 6 : AppThemeData.spacingSmall,
                  vertical: 10,
                ),
                decoration: _buildItemDecoration(theme),
                child: isCollapsed
                    ? _buildCollapsedItem(theme)
                    : _buildExpandedItem(context, theme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildItemDecoration(ThemeData theme) {
    return BoxDecoration(
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
      border: Border.all(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.3)
            : Colors.transparent,
        width: 1,
      ),
    );
  }

  Widget _buildCollapsedItem(ThemeData theme) {
    return Center(child: _buildIcon(theme));
  }

  Widget _buildExpandedItem(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        _buildIcon(theme),
        const SizedBox(width: AppThemeData.spacingSmall),
        _buildTitle(theme),
        if (item.badge != null) _buildBadge(context, theme),
      ],
    );
  }

  Widget _buildIcon(ThemeData theme) {
    return Icon(
      isSelected && item.activeIcon != null ? item.activeIcon : item.icon,
      color: _getItemColor(theme),
      size: _iconSize,
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Expanded(
      child: Opacity(
        opacity: fadeAnimation.value,
        child: Text(
          item.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _getItemColor(theme),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context, ThemeData theme) {
    final currentTheme = context.read<ThemeProvider>().currentTheme;

    return Opacity(
      opacity: fadeAnimation.value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: currentTheme.accentColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.surface, width: 1),
        ),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        child: Text(
          item.badge!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Color _getItemColor(ThemeData theme) {
    return isSelected
        ? theme.colorScheme.primary
        : AppThemeData.getTextColor(theme, isPrimary: false);
  }

  String _buildSemanticsLabel(BuildContext context) {
    if (item.badge == null || item.badge!.isEmpty) {
      return item.title;
    }
    return '${item.title}, ${LocalizationKeys.badgeLabel.tr(context)} ${item.badge}';
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

class _DefaultSidebarMiniCard extends SidebarMiniCard {
  _DefaultSidebarMiniCard()
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

class _ConnectedSidebarMiniCard extends SidebarMiniCard {
  _ConnectedSidebarMiniCard()
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
    final info = _SidebarMiniStageResolver.buildStageInfo(home);
    if (isCollapsed) {
      final icon = switch (info.stage) {
        _MiniFlightStage.ground => Icons.local_airport_rounded,
        _MiniFlightStage.climb => Icons.trending_up_rounded,
        _MiniFlightStage.cruise => Icons.flight_rounded,
        _MiniFlightStage.descent => Icons.trending_down_rounded,
        _MiniFlightStage.approach => Icons.flight_land_rounded,
      };

      return Tooltip(
        key: const ValueKey('mini_info_connected_collapsed'),
        message: info.tooltip,
        child: _MiniCardContainer(
          theme: theme,
          isCollapsed: true,
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
      );
    }

    return Tooltip(
      key: const ValueKey('mini_info_connected_expanded'),
      message: info.tooltip,
      child: _MiniCardContainer(
        theme: theme,
        isCollapsed: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.stageName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
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
    if (data.onGround == true) return _MiniFlightStage.ground;
    final altitude = data.altitude ?? 0;
    final verticalSpeed = data.verticalSpeed ?? 0;
    final groundSpeed = data.groundSpeed ?? 0;
    final approachLike =
        altitude <= 5000 &&
        verticalSpeed <= -300 &&
        (groundSpeed <= 220 ||
            data.gearDown == true ||
            data.flapsDeployed == true);
    if (approachLike) return _MiniFlightStage.approach;
    if (verticalSpeed >= 300) return _MiniFlightStage.climb;
    if (verticalSpeed <= -300) return _MiniFlightStage.descent;
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
