import 'package:flutter/material.dart';
import '../../module_registry/navigation/navigation_item.dart';
import '../../module_registry/module_registry.dart';
import '../../theme/app_theme_data.dart';
import '../../localization/localization_keys.dart';
import '../../services/localization_service.dart';

/// 移动端底部导航栏组件
/// 参考Instagram、WeChat、Telegram的设计风格
class MobileBottomNavbar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            children: List.generate(
              items.length,
              (index) => _buildNavItem(
                context,
                items[index],
                index,
                theme,
                ModuleRegistry().navigationAvailability.isEnabled(
                  context,
                  items[index],
                ),
              ),
            ),
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
    final isSelected = selectedIndex == index;
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
              onTap: isEnabled ? () => onItemSelected(index) : null,
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
                                color: _getItemColor(theme, isSelected, isEnabled),
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

  Color _getItemColor(ThemeData theme, bool isSelected, bool isEnabled) {
    if (!isEnabled) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.45);
    }
    return isSelected
        ? theme.colorScheme.primary
        : AppThemeData.getTextColor(theme);
  }
}
