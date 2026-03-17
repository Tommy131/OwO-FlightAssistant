import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/module_registry/sidebar/sidebar_title_badge.dart';
import '../../../core/services/localization_service.dart';
import '../localization/common_localization_keys.dart';
import '../providers/home_provider.dart';

class CommonBackendStatusSidebarTitleBadge extends SidebarTitleBadge {
  CommonBackendStatusSidebarTitleBadge()
    : super(id: 'common_backend_status_title_badge', priority: 100);

  @override
  bool canDisplay(BuildContext context) {
    return context.watch<HomeProvider?>() != null;
  }

  @override
  Widget build(
    BuildContext context, {
    required ThemeData theme,
    required bool isCollapsed,
  }) {
    final reachable =
        context.watch<HomeProvider?>()?.isBackendReachable ?? false;
    final color = reachable ? const Color(0xFF2E7D32) : theme.colorScheme.error;
    final text = reachable
        ? CommonLocalizationKeys.backendAvailableLabel.tr(context)
        : CommonLocalizationKeys.backendUnavailableTitle.tr(context);

    if (isCollapsed) {
      return Tooltip(
        message: text,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
