import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/navigation_item.dart';
import '../../theme/app_theme_data.dart';
import '../../theme/theme_provider.dart';

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
        // 搜索按钮
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            // TODO: 实现搜索功能
          },
          tooltip: '搜索',
        ),
        const SizedBox(width: AppThemeData.spacingSmall),
        // 通知按钮
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                // TODO: 实现通知功能
              },
              tooltip: '通知',
            ),
            // 未读通知徽章
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: AppThemeData.spacingSmall),
        // 主题选择器
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return PopupMenuButton<ThemeMode>(
              icon: Icon(
                themeProvider.getThemeModeIcon(themeProvider.themeMode),
              ),
              tooltip: '主题设置',
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
                        themeProvider.getThemeModeName(mode),
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
        const SizedBox(width: AppThemeData.spacingSmall),
      ],
    );
  }
}
