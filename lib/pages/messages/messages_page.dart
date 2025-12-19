import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme_data.dart';
import '../../core/theme/theme_provider.dart';

/// 消息页面示例
class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // 搜索栏
          Container(
            padding: const EdgeInsets.all(AppThemeData.spacingMedium),
            color: theme.colorScheme.surface,
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索消息...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppThemeData.borderRadiusMedium,
                  ),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
              ),
            ),
          ),

          // 消息列表
          Expanded(
            child: ListView.builder(
              itemCount: 15,
              itemBuilder: (context, index) {
                return _buildMessageItem(context, theme, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(BuildContext context, ThemeData theme, int index) {
    final hasUnread = index % 3 == 0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: AppThemeData.getBorderColor(theme),
            width: 0.5,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppThemeData.spacingMedium,
          vertical: AppThemeData.spacingSmall,
        ),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              child: Text(
                'U${index + 1}',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (hasUnread)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: context
                        .read<ThemeProvider>()
                        .currentTheme
                        .accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '用户 ${index + 1}',
                style: TextStyle(
                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            Text(
              '${index + 1}分钟前',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '这是一条消息预览文本，展示最新的消息内容...',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
              color: hasUnread
                  ? AppThemeData.getTextColor(theme)
                  : AppThemeData.getTextColor(theme, isPrimary: false),
            ),
          ),
        ),
        trailing: hasUnread
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '3',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: () {
          // TODO: 打开消息详情
        },
      ),
    );
  }
}
