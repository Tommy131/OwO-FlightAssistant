import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../theme/app_theme_data.dart';
import '../../module_registry/navigation/navigation_item.dart';
import '../../theme/theme_provider.dart';
import '../../localization/localization_keys.dart';
import '../../services/localization_service.dart';
import '../../module_registry/module_registry.dart';
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
