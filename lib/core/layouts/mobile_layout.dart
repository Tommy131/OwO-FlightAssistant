import 'package:flutter/material.dart';
import '../module_registry/module_registry.dart';
import '../module_registry/app_bar/app_bar_action.dart';
import '../module_registry/navigation/navigation_item.dart';
import '../theme/app_theme_data.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/mobile/bottom_navbar.dart';

/// 移动端布局
/// 上：AppBar
/// 中：主内容区
/// 下：BottomNavbar
class MobileLayout extends StatelessWidget {
  final List<NavigationItem> navigationItems;
  final int selectedIndex;
  final Function(int) onNavigationChanged;

  const MobileLayout({
    super.key,
    required this.navigationItems,
    required this.selectedIndex,
    required this.onNavigationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentItem = navigationItems[selectedIndex];
    final sideMenus = ModuleRegistry().appBarActions.getSideMenus(
      currentItem.id,
    );

    return Scaffold(
      appBar: CustomAppBar.build(
        currentItem,
        context,
        hasSideMenu: sideMenus.isNotEmpty,
      ),
      drawer: sideMenus.isEmpty
          ? null
          : _ModuleSideMenuDrawer(item: currentItem, entries: sideMenus),
      body: currentItem.page,
      bottomNavigationBar: MobileBottomNavbar(
        items: navigationItems,
        selectedIndex: selectedIndex,
        onItemSelected: onNavigationChanged,
      ),
    );
  }
}

class _ModuleSideMenuDrawer extends StatelessWidget {
  final NavigationItem item;
  final List<AppBarSideMenuEntry> entries;

  const _ModuleSideMenuDrawer({required this.item, required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupedListenables = entries
        .map((entry) => entry.stateListenable)
        .whereType<Listenable>()
        .toList();

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Container(
              padding: const EdgeInsets.all(AppThemeData.spacingMedium),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.18),
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(
                  AppThemeData.borderRadiusLarge,
                ),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(
                        AppThemeData.borderRadiusMedium,
                      ),
                    ),
                    child: Icon(item.icon, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: AppThemeData.spacingMedium),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            if (groupedListenables.isEmpty)
              ...entries.map((entry) => _buildEntry(context, entry))
            else
              AnimatedBuilder(
                animation: Listenable.merge(groupedListenables),
                builder: (context, _) {
                  return Column(
                    children: entries
                        .map((entry) => _buildEntry(context, entry))
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(BuildContext context, AppBarSideMenuEntry entry) {
    final theme = Theme.of(context);
    final selected = entry.isSelected?.call(context) ?? false;
    final highlightColor = theme.colorScheme.primary;
    final selectedTextColor = theme.colorScheme.onPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppThemeData.borderRadiusLarge),
          onTap: () {
            Navigator.of(context).pop();
            entry.onTap(context);
          },
          child: AnimatedContainer(
            duration: AppThemeData.animationDuration,
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        highlightColor.withValues(alpha: 0.95),
                        highlightColor.withValues(alpha: 0.72),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: selected
                  ? null
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.2,
                    ),
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusLarge,
              ),
              border: Border.all(
                color: selected
                    ? highlightColor.withValues(alpha: 0.98)
                    : theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: highlightColor.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppThemeData.animationDuration,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.2)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(
                      AppThemeData.borderRadiusMedium,
                    ),
                  ),
                  child: Icon(
                    entry.icon,
                    color: selected
                        ? selectedTextColor
                        : theme.colorScheme.outline,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.titleBuilder(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: selected
                          ? selectedTextColor
                          : theme.colorScheme.onSurface.withValues(alpha: 0.9),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
