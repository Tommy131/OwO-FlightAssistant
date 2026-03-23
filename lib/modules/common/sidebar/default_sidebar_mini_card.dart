import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/module_registry/sidebar/sidebar_mini_card.dart';
import '../../../core/theme/app_theme_data.dart';
import '../providers/flight_data_provider.dart';

/// 默认侧边栏迷你卡片（未连接模拟器时显示应用名称与版本号）
class HomeDefaultSidebarMiniCard extends SidebarMiniCard {
  HomeDefaultSidebarMiniCard()
    : super(id: 'default_app_mini_card', priority: 1000);

  @override
  bool canDisplay(BuildContext context) {
    final provider = context.watch<FlightDataProvider?>();
    return provider == null || !provider.isConnected;
  }

  @override
  Widget build(
    BuildContext context, {
    required ThemeData theme,
    required bool isCollapsed,
  }) {
    if (isCollapsed) {
      return Tooltip(
        key: const ValueKey('mini_info_collapsed'),
        message: '${AppConstants.appName} ${AppConstants.appVersion}',
        child: _MiniCardBox(
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

    return _MiniCardBox(
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

/// 可复用的迷你卡片基础容器样式
class _MiniCardBox extends StatelessWidget {
  final ThemeData theme;
  final bool isCollapsed;
  final Widget child;

  const _MiniCardBox({
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
