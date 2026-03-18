import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../module_registry/navigation/navigation_item.dart';
import '../../module_registry/navigation/navigation_registry.dart';
import '../../module_registry/navigation/navigation_group.dart';
import '../../theme/theme_provider.dart';
import '../../theme/app_theme_data.dart';
import '../../constants/app_constants.dart';
import '../../localization/localization_keys.dart';
import '../../services/localization_service.dart';
import '../../module_registry/module_registry.dart';

/// 桌面端侧边栏组件（紧凑型）
/// 支持展开/折叠，带有流畅的动画过渡
class DesktopSidebar extends StatefulWidget {
  final List<NavigationElement> elements;
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool initiallyExpanded;

  const DesktopSidebar({
    super.key,
    required this.elements,
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
  final Map<String, bool> _expandedGroups = {};

  // 提取常量，避免硬编码
  static const double _collapsedThreshold = 100.0;
  static const double _iconSize = 20.0;
  static const double _logoSize = 32.0;
  static const double _headerHeight = 56.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeGroups();
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

  void _initializeGroups() {
    for (final element in widget.elements) {
      if (element.isGroup) {
        _expandedGroups[element.group!.id] = element.group!.initiallyExpanded;
      }
    }
  }

  @override
  void didUpdateWidget(DesktopSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.elements != widget.elements) {
      // 保持现有的展开状态，仅添加新的分组
      for (final element in widget.elements) {
        if (element.isGroup &&
            !_expandedGroups.containsKey(element.group!.id)) {
          _expandedGroups[element.group!.id] = element.group!.initiallyExpanded;
        }
      }
    }
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

  void _toggleGroup(String groupId) {
    if (!_isExpanded) {
      _toggleSidebar();
    }
    setState(() {
      _expandedGroups[groupId] = !(_expandedGroups[groupId] ?? true);
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
    final titleBadge = ModuleRegistry().sidebarTitleBadge.resolve(context);
    return Expanded(
      child: _buildFadeTransition(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titleBadge != null) ...[
              const SizedBox(height: 2),
              titleBadge.build(context, theme: theme, isCollapsed: false),
            ] else ...[
              Text(
                LocalizationKeys.userGreeting.tr(context),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedHeader(ThemeData theme) {
    final titleBadge = ModuleRegistry().sidebarTitleBadge.resolve(context);
    return Center(
      child: Semantics(
        button: true,
        label: LocalizationKeys.expandSidebar.tr(context),
        child: Tooltip(
          message: LocalizationKeys.expandSidebar.tr(context),
          child: InkWell(
            onTap: _toggleSidebar,
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ExcludeSemantics(child: _buildLogo(theme)),
                if (titleBadge != null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: titleBadge.build(
                      context,
                      theme: theme,
                      isCollapsed: true,
                    ),
                  ),
              ],
            ),
          ),
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
    // 计算扁平化的索引
    int flatIndexCounter = 0;
    final List<Widget> listItems = [];

    for (final element in widget.elements) {
      if (element.isGroup) {
        final group = element.group!;
        final isGroupExpanded = _expandedGroups[group.id] ?? true;

        listItems.add(
          _GroupItemWidget(
            group: group,
            isExpanded: isGroupExpanded,
            isCollapsed: _isCollapsed,
            onTap: () => _toggleGroup(group.id),
            fadeAnimation: _fadeAnimation,
          ),
        );

        if (isGroupExpanded || _isCollapsed) {
          for (final item in element.children) {
            final currentIndex = flatIndexCounter++;
            listItems.add(
              _NavigationItemWidget(
                item: item,
                index: currentIndex,
                isSelected: widget.selectedIndex == currentIndex,
                isEnabled: ModuleRegistry().navigationAvailability.isEnabled(
                  context,
                  item,
                ),
                isCollapsed: _isCollapsed,
                isSubItem: true,
                fadeAnimation: _fadeAnimation,
                onTap: () => widget.onItemSelected(currentIndex),
              ),
            );
          }
        } else {
          // 即使分组折叠了，也要增加计数器以保持索引一致
          flatIndexCounter += element.children.length;
        }
      } else if (element.item != null) {
        final currentIndex = flatIndexCounter++;
        listItems.add(
          _NavigationItemWidget(
            item: element.item!,
            index: currentIndex,
            isSelected: widget.selectedIndex == currentIndex,
            isEnabled: ModuleRegistry().navigationAvailability.isEnabled(
              context,
              element.item!,
            ),
            isCollapsed: _isCollapsed,
            isSubItem: false,
            fadeAnimation: _fadeAnimation,
            onTap: () => widget.onItemSelected(currentIndex),
          ),
        );
      }
    }

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppThemeData.spacingSmall,
        ),
        children: listItems,
      ),
    );
  }

  Widget _buildMiniInfoCard(ThemeData theme) {
    final card = ModuleRegistry().sidebarMiniCards.resolve(context);
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
          child: card.build(context, theme: theme, isCollapsed: _isCollapsed),
        ),
      ),
    );
  }

  Widget _buildFadeTransition({required Widget child}) {
    return Opacity(opacity: _fadeAnimation.value, child: child);
  }
}

/// 分组标题组件
class _GroupItemWidget extends StatelessWidget {
  final NavigationGroup group;
  final bool isExpanded;
  final bool isCollapsed;
  final VoidCallback onTap;
  final Animation<double> fadeAnimation;

  const _GroupItemWidget({
    required this.group,
    required this.isExpanded,
    required this.isCollapsed,
    required this.onTap,
    required this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Icon(
            group.icon,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4, right: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              Icon(
                group.icon,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Opacity(
                  opacity: fadeAnimation.value,
                  child: Text(
                    group.title.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Opacity(
                opacity: fadeAnimation.value,
                child: Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 导航项组件（提取为独立组件以提高复用性）
class _NavigationItemWidget extends StatelessWidget {
  final NavigationItem item;
  final int index;
  final bool isSelected;
  final bool isEnabled;
  final bool isCollapsed;
  final bool isSubItem;
  final Animation<double> fadeAnimation;
  final VoidCallback onTap;

  const _NavigationItemWidget({
    required this.item,
    required this.index,
    required this.isSelected,
    required this.isEnabled,
    required this.isCollapsed,
    this.isSubItem = false,
    required this.fadeAnimation,
    required this.onTap,
  });

  static const double _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: 4,
        left: isSubItem && !isCollapsed ? 12 : 0,
      ),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          container: true,
          button: true,
          selected: isSelected,
          label: _buildSemanticsLabel(context),
          onTap: isEnabled ? onTap : null,
          enabled: isEnabled,
          focusable: true,
          child: ExcludeSemantics(
            child: InkWell(
              onTap: isEnabled ? onTap : null,
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusSmall,
              ),
              child: AnimatedOpacity(
                duration: AppThemeData.animationDuration,
                opacity: isEnabled ? 1 : 0.5,
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
      ),
    );
  }

  BoxDecoration _buildItemDecoration(ThemeData theme) {
    if (!isEnabled) {
      return BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
        border: Border.all(color: AppThemeData.getBorderColor(theme), width: 1),
      );
    }
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
    if (!isEnabled) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.45);
    }
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
