import 'package:flutter/material.dart';

import '../../core/theme/app_theme_data.dart';

/// 个人资料页面示例
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // 个人信息卡片
            _buildProfileHeader(theme),

            const SizedBox(height: AppThemeData.spacingLarge),

            // 统计信息
            _buildStatsSection(theme),

            const SizedBox(height: AppThemeData.spacingLarge),

            // 设置选项
            _buildSettingsSection(theme),

            const SizedBox(height: AppThemeData.spacingLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingXLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // 头像
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person,
                size: 50,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(height: AppThemeData.spacingMedium),

          // 用户名
          const Text(
            '用户名',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: AppThemeData.spacingSmall),

          // 邮箱
          Text(
            'user@example.com',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
            ),
          ),

          const SizedBox(height: AppThemeData.spacingLarge),

          // 编辑按钮
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit),
            label: const Text('编辑资料'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppThemeData.spacingLarge,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppThemeData.spacingLarge),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
          border: Border.all(color: AppThemeData.getBorderColor(theme)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(theme, '1,234', '帖子'),
            _buildDivider(theme),
            _buildStatItem(theme, '5,678', '关注'),
            _buildDivider(theme),
            _buildStatItem(theme, '9,012', '粉丝'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Container(
      width: 1,
      height: 40,
      color: AppThemeData.getBorderColor(theme),
    );
  }

  Widget _buildSettingsSection(ThemeData theme) {
    final settingsItems = [
      {'icon': Icons.account_circle, 'title': '账号设置', 'subtitle': '管理你的账号信息'},
      {'icon': Icons.notifications, 'title': '通知设置', 'subtitle': '管理通知偏好'},
      {'icon': Icons.privacy_tip, 'title': '隐私设置', 'subtitle': '控制你的隐私'},
      {'icon': Icons.security, 'title': '安全设置', 'subtitle': '密码和安全选项'},
      {'icon': Icons.language, 'title': '语言设置', 'subtitle': '选择显示语言'},
      {'icon': Icons.help, 'title': '帮助中心', 'subtitle': '获取帮助和支持'},
      {'icon': Icons.info, 'title': '关于', 'subtitle': '应用信息和版本'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppThemeData.spacingLarge,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
          border: Border.all(color: AppThemeData.getBorderColor(theme)),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: settingsItems.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            indent: 72,
            color: AppThemeData.getBorderColor(theme),
          ),
          itemBuilder: (context, index) {
            final item = settingsItems[index];
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    AppThemeData.borderRadiusSmall,
                  ),
                ),
                child: Icon(
                  item['icon'] as IconData,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              title: Text(item['title'] as String),
              subtitle: Text(item['subtitle'] as String),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: 处理设置项点击
              },
            );
          },
        ),
      ),
    );
  }
}
