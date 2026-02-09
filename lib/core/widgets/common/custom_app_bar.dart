import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../apps/providers/simulator/simulator_provider.dart';
import '../../../../apps/services/flight_log_service.dart';

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
        // 飞行日志导入/导出
        IconButton(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: '导入飞行轨迹',
          onPressed: () async {
            final success = await FlightLogService().importLog();
            if (success && context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('飞行轨迹导入成功')));
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.file_upload_outlined),
          tooltip: '导出当前飞行轨迹',
          onPressed: () async {
            final sim = context.read<SimulatorProvider>();
            if (sim.canExportCurrentLog) {
              await FlightLogService().exportLog(sim.currentFlightLog!);
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(sim.exportValidationMessage ?? '当前状态无法导出数据'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          },
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
