import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme_data.dart';
import '../../models/navigation_item.dart';
import '../../theme/theme_provider.dart';
import '../../../apps/providers/simulator/simulator_provider.dart';
import '../../../apps/models/simulator_data.dart';

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
  static const double _avatarRadius = 16.0;
  static const double _headerHeight = 56.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
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
              _buildFooter(theme),
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
      child: _buildIconButton(
        icon: Icons.menu,
        tooltip: '展开侧边栏',
        onPressed: _toggleSidebar,
        theme: theme,
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
          tooltip: '折叠侧边栏',
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
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.face, color: Colors.white, size: _iconSize),
    );
  }

  Widget _buildLogoText(ThemeData theme) {
    return Expanded(
      child: _buildFadeTransition(
        child: Text(
          '你好!',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 15,
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
    return IconButton(
      icon: Icon(icon, color: theme.colorScheme.primary, size: _iconSize),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: _logoSize,
        minHeight: _logoSize,
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

  Widget _buildFooter(ThemeData theme) {
    return Consumer<SimulatorProvider>(
      builder: (context, simProvider, _) {
        final data = simProvider.simulatorData;

        // 如果未连接模拟器，不显示页脚
        if (!simProvider.isConnected) {
          return const SizedBox.shrink();
        }

        final nearest = simProvider.nearestAirport;
        final departure = data.departureAirport;
        final phase = simProvider.flightPhase;
        final phaseIcon = simProvider.flightPhaseIcon;
        final weather = simProvider.weatherQuality;
        final weatherIcon = simProvider.weatherIcon;
        final dist = simProvider.remainingDistance;
        final ete = simProvider.estimatedTimeEnroute;

        // 优先显示：机场信息。如果没有机场信息，则显示飞行阶段+天气
        final airportName = (data.onGround == false && nearest != null)
            ? '${nearest.icaoCode} ${nearest.nameChinese}'
            : (departure ??
                  (nearest != null
                      ? '${nearest.icaoCode} ${nearest.nameChinese}'
                      : null));

        return Container(
          padding: EdgeInsets.all(_isCollapsed ? 4 : AppThemeData.spacingSmall),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AppThemeData.getBorderColor(theme),
                width: 1,
              ),
            ),
          ),
          child: _isCollapsed
              ? _buildCollapsedFooter(
                  theme,
                  airportName ?? phase,
                  airportName != null ? Icons.flight_takeoff : phaseIcon,
                )
              : _buildExpandedFooter(
                  theme,
                  data,
                  airportName,
                  phase,
                  phaseIcon,
                  weather,
                  weatherIcon,
                  dist,
                  ete,
                ),
        );
      },
    );
  }

  Widget _buildCollapsedFooter(ThemeData theme, String tooltip, IconData icon) {
    return Center(
      child: Tooltip(
        message: tooltip,
        child: CircleAvatar(
          radius: _avatarRadius,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildExpandedFooter(
    ThemeData theme,
    SimulatorData data,
    String? airportName,
    String phase,
    IconData phaseIcon,
    String weather,
    IconData weatherIcon,
    double? distance,
    String? ete,
  ) {
    final distText = distance != null
        ? ' | ${distance.toStringAsFixed(0)} NM'
        : '';
    final eteText = ete != null ? ' | ETE $ete' : '';
    final comText = data.com1Frequency != null
        ? '${data.com1Frequency!.toStringAsFixed(3)} MHz'
        : '';
    final visText = data.visibility != null
        ? ' | VIS ${(data.visibility! / 1000).toStringAsFixed(1)} KM'
        : '';

    final mainText = airportName ?? (data.onGround == true ? '未知机场' : phase);
    final subText = data.onGround == true
        ? '$comText$visText'
        : (airportName != null
              ? '$phase$distText$eteText'
              : '$weather$eteText');

    final mainIcon = airportName != null ? Icons.flight_takeoff : phaseIcon;

    return Row(
      children: [
        CircleAvatar(
          radius: _avatarRadius,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(mainIcon, size: 16, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: AppThemeData.spacingSmall),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mainText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  if (airportName == null) ...[
                    Icon(weatherIcon, size: 10, color: theme.hintColor),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      subText,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
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
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
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
}
