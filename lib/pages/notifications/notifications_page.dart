import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme_data.dart';
import '../../core/theme/theme_provider.dart';

/// 通知页面示例
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        itemCount: 12,
        itemBuilder: (context, index) {
          return _buildNotificationItem(context, theme, index);
        },
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    ThemeData theme,
    int index,
  ) {
    final isUnread = index % 4 == 0;

    final notificationTypes = [
      {'icon': Icons.favorite, 'color': Colors.red, 'type': '点赞'},
      {'icon': Icons.comment, 'color': theme.colorScheme.primary, 'type': '评论'},
      {
        'icon': Icons.person_add,
        'color': context.read<ThemeProvider>().currentTheme.accentColor,
        'type': '关注',
      },
      {'icon': Icons.share, 'color': theme.colorScheme.secondary, 'type': '分享'},
    ];

    final notification = notificationTypes[index % notificationTypes.length];

    return Container(
      margin: const EdgeInsets.only(bottom: AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: isUnread
              ? (notification['color'] as Color).withValues(alpha: 0.3)
              : AppThemeData.getBorderColor(theme),
          width: isUnread ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppThemeData.spacingMedium),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: (notification['color'] as Color).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            notification['icon'] as IconData,
            color: notification['color'] as Color,
            size: 24,
          ),
        ),
        title: RichText(
          text: TextSpan(
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
            ),
            children: [
              const TextSpan(text: '用户名 '),
              TextSpan(
                text: notification['type'] as String,
                style: TextStyle(
                  color: notification['color'] as Color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: ' 了你的内容'),
            ],
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${index + 1}小时前',
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
        ),
        trailing: isUnread
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: notification['color'] as Color,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }
}
