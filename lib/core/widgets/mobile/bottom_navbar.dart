import 'package:flutter/material.dart';
import '../../module_registry/navigation/navigation_item.dart';
import '../../module_registry/module_registry.dart';
import '../../theme/app_theme_data.dart';
import '../../localization/localization_keys.dart';
import '../../services/localization_service.dart';

class MobileBottomNavbar extends StatefulWidget {
  final List<NavigationItem> items;
  final int selectedIndex;
  final Function(int) onItemSelected;

  const MobileBottomNavbar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<MobileBottomNavbar> createState() => _MobileBottomNavbarState();
}

class _MobileBottomNavbarState extends State<MobileBottomNavbar> {
  String _moreLabel(BuildContext context) {
    return LocalizationService().currentLanguageCode == 'zh_CN' ? '更多' : 'More';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final maxSlots = width < 360 ? 4 : 5;
    final hasOverflow = widget.items.length > maxSlots;
    final primaryCount = hasOverflow ? maxSlots - 1 : widget.items.length;
    final primaryItems = widget.items.take(primaryCount).toList();
    final overflowItems = hasOverflow
        ? widget.items.sublist(primaryCount)
        : const <NavigationItem>[];
    final overflowStartIndex = primaryCount;
    final isMoreSelected = hasOverflow && widget.selectedIndex >= primaryCount;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: AppThemeData.getBorderColor(theme),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppThemeData.spacingSmall,
            vertical: 6,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ...List.generate(
                primaryItems.length,
                (index) => _buildNavItem(
                  context,
                  primaryItems[index],
                  index,
                  theme,
                  ModuleRegistry().navigationAvailability.isEnabled(
                    context,
                    primaryItems[index],
                  ),
                ),
              ),
              if (hasOverflow)
                _buildMoreNavItem(
                  context: context,
                  theme: theme,
                  isSelected: isMoreSelected,
                  label: _moreLabel(context),
                  hasEnabledItem: overflowItems.any(
                    (item) => ModuleRegistry().navigationAvailability.isEnabled(
                      context,
                      item,
                    ),
                  ),
                  overflowItems: overflowItems,
                  overflowStartIndex: overflowStartIndex,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    NavigationItem item,
    int index,
    ThemeData theme,
    bool isEnabled,
  ) {
    final isSelected = widget.selectedIndex == index;
    final label = item.badge == null || item.badge!.isEmpty
        ? item.title
        : '${item.title}, ${LocalizationKeys.badgeLabel.tr(context)} ${item.badge}';

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          button: true,
          selected: isSelected,
          label: label,
          enabled: isEnabled,
          child: ExcludeSemantics(
            child: InkWell(
              onTap: isEnabled ? () => widget.onItemSelected(index) : null,
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusSmall,
              ),
              child: AnimatedOpacity(
                duration: AppThemeData.animationDuration,
                opacity: isEnabled ? 1 : 0.5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 28,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            AnimatedScale(
                              scale: isSelected ? 1.1 : 1.0,
                              duration: AppThemeData.animationDuration,
                              curve: Curves.easeInOut,
                              child: Icon(
                                isSelected && item.activeIcon != null
                                    ? item.activeIcon
                                    : item.icon,
                                color: _getItemColor(
                                  theme,
                                  isSelected,
                                  isEnabled,
                                ),
                                size: 24,
                              ),
                            ),
                            if (item.badge != null)
                              Positioned(
                                right: -8,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: theme.colorScheme.surface,
                                      width: 1.5,
                                    ),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    item.badge!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isSelected ? 11 : 10,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _getItemColor(theme, isSelected, isEnabled),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreNavItem({
    required BuildContext context,
    required ThemeData theme,
    required bool isSelected,
    required String label,
    required bool hasEnabledItem,
    required List<NavigationItem> overflowItems,
    required int overflowStartIndex,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          button: true,
          selected: isSelected,
          label: label,
          enabled: hasEnabledItem,
          child: ExcludeSemantics(
            child: InkWell(
              onTap: hasEnabledItem
                  ? () => _showOverflowSheet(
                      context: context,
                      theme: theme,
                      overflowItems: overflowItems,
                      overflowStartIndex: overflowStartIndex,
                    )
                  : null,
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusSmall,
              ),
              child: AnimatedOpacity(
                duration: AppThemeData.animationDuration,
                opacity: hasEnabledItem ? 1 : 0.5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 28,
                        child: AnimatedScale(
                          scale: isSelected ? 1.1 : 1.0,
                          duration: AppThemeData.animationDuration,
                          curve: Curves.easeInOut,
                          child: Icon(
                            isSelected
                                ? Icons.apps_rounded
                                : Icons.grid_view_rounded,
                            color: _getItemColor(
                              theme,
                              isSelected,
                              hasEnabledItem,
                            ),
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isSelected ? 11 : 10,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _getItemColor(
                            theme,
                            isSelected,
                            hasEnabledItem,
                          ),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showOverflowSheet({
    required BuildContext context,
    required ThemeData theme,
    required List<NavigationItem> overflowItems,
    required int overflowStartIndex,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return ListView.separated(
          shrinkWrap: true,
          itemCount: overflowItems.length,
          separatorBuilder: (_, index) =>
              Divider(height: 1, color: AppThemeData.getBorderColor(theme)),
          itemBuilder: (_, localIndex) {
            final globalIndex = overflowStartIndex + localIndex;
            final item = overflowItems[localIndex];
            final isSelected = widget.selectedIndex == globalIndex;
            final isEnabled = ModuleRegistry().navigationAvailability.isEnabled(
              context,
              item,
            );

            return ListTile(
              enabled: isEnabled,
              onTap: isEnabled
                  ? () {
                      Navigator.of(sheetContext).pop();
                      widget.onItemSelected(globalIndex);
                    }
                  : null,
              leading: Icon(
                isSelected && item.activeIcon != null
                    ? item.activeIcon
                    : item.icon,
                color: _getItemColor(theme, isSelected, isEnabled),
              ),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: item.badge == null || item.badge!.isEmpty
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              selected: isSelected,
            );
          },
        );
      },
    );
  }

  Color _getItemColor(ThemeData theme, bool isSelected, bool isEnabled) {
    if (!isEnabled) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.45);
    }
    return isSelected
        ? theme.colorScheme.primary
        : AppThemeData.getTextColor(theme);
  }
}
