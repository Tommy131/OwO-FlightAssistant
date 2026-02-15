import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../module_registry/module_registry.dart';
import '../../module_registry/navigation/navigation_item.dart';
import '../../theme/app_theme_data.dart';
import '../../theme/theme_provider.dart';
import '../../localization/localization_keys.dart';
import '../../services/localization_service.dart';

class CustomAppBar {
  static PreferredSizeWidget build(
    NavigationItem currentItem,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    return AppBar(
      title: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              currentItem.activeIcon ?? currentItem.icon,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppThemeData.spacingSmall),
          Text(currentItem.title),
        ],
      ),
      // 右侧操作按钮
      actions: [
        // 动态加载已注册的操作按钮
        ...ModuleRegistry().appBarActions.getAllActions().expand(
          (action) => [
            action.build(context),
            const SizedBox(width: AppThemeData.spacingSmall),
          ],
        ),

        // 主题选择器
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return PopupMenuButton<ThemeMode>(
              icon: Icon(
                themeProvider.getThemeModeIcon(themeProvider.themeMode),
              ),
              tooltip: LocalizationKeys.themeSettingsTooltip.tr(context),
              onSelected: (ThemeMode mode) {
                themeProvider.setThemeMode(mode);
              },
              itemBuilder: (context) => ThemeMode.values.map((mode) {
                return PopupMenuItem<ThemeMode>(
                  value: mode,
                  child: Row(
                    children: [
                      Icon(
                        themeProvider.getThemeModeIcon(mode),
                        size: 20,
                        color: themeProvider.themeMode == mode
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: AppThemeData.spacingMedium),
                      Text(
                        themeProvider.getThemeModeName(context, mode),
                        style: TextStyle(
                          color: themeProvider.themeMode == mode
                              ? theme.colorScheme.primary
                              : null,
                          fontWeight: themeProvider.themeMode == mode
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      if (themeProvider.themeMode == mode) ...[
                        const Spacer(),
                        Icon(
                          Icons.check,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(width: AppThemeData.spacingMedium),
      ],
    );
  }
}
