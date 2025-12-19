import 'package:flutter/material.dart';
import 'package:owo_dashboard/core/theme/theme_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme_data.dart';

/// 首页示例
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppThemeData.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 欢迎卡片
            _buildWelcomeCard(theme),

            const SizedBox(height: AppThemeData.spacingLarge),

            // 统计卡片网格
            _buildStatsGrid(context, theme),

            const SizedBox(height: AppThemeData.spacingLarge),

            // 最近活动
            _buildRecentActivity(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '欢迎回来！',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppThemeData.spacingSmall),
          Text(
            '这是一个现代化的跨平台应用框架',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppThemeData.spacingLarge),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.rocket_launch),
            label: const Text('开始使用'),
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

  Widget _buildStatsGrid(BuildContext context, ThemeData theme) {
    final stats = [
      {
        'title': '总用户',
        'value': '12,345',
        'icon': Icons.people,
        'color': theme.colorScheme.primary,
      },
      {
        'title': '活跃用户',
        'value': '8,901',
        'icon': Icons.trending_up,
        'color': context.read<ThemeProvider>().currentTheme.accentColor,
      },
      {
        'title': '新消息',
        'value': '234',
        'icon': Icons.message,
        'color': theme.colorScheme.secondary,
      },
      {
        'title': '待处理',
        'value': '56',
        'icon': Icons.pending_actions,
        'color': Colors.orange,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        bool minimum = false;
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;

        // 动态计算宽高比，防止内容溢出
        double childAspectRatio = 1.5;
        if (constraints.maxWidth > 1100) {
          childAspectRatio = 1.5;
        } else if (constraints.maxWidth > 800) {
          // 平板/小桌面 4列模式，卡片较窄
          childAspectRatio = 1.2;
        } else if (constraints.maxWidth > 520) {
          // 普通手机 2列模式
          childAspectRatio = 1.5;
        } else if (constraints.maxWidth > 450) {
          // 小屏手机 2列模式
          childAspectRatio = 1.2;
        } else {
          // 超小屏手机 2列模式，需要更高的高度
          childAspectRatio = 1.0;
          minimum = true;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: !minimum ? crossAxisCount : 1,
            crossAxisSpacing: AppThemeData.spacingMedium,
            mainAxisSpacing: AppThemeData.spacingMedium,
            childAspectRatio: !minimum ? childAspectRatio : 2,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];
            return _buildStatCard(
              context,
              theme,
              stat['title'] as String,
              stat['value'] as String,
              stat['icon'] as IconData,
              stat['color'] as Color,
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(color: AppThemeData.getBorderColor(theme)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    AppThemeData.borderRadiusSmall,
                  ),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Icon(
                Icons.arrow_upward,
                color: context.read<ThemeProvider>().currentTheme.accentColor,
                size: 16,
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: theme.textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('最近活动', style: theme.textTheme.displaySmall),
        const SizedBox(height: AppThemeData.spacingMedium),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(
              AppThemeData.borderRadiusMedium,
            ),
            border: Border.all(color: AppThemeData.getBorderColor(theme)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: AppThemeData.getBorderColor(theme)),
            itemBuilder: (context, index) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  child: Icon(
                    Icons.notifications,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text('活动标题 ${index + 1}'),
                subtitle: Text('这是活动的详细描述...'),
                trailing: Text(
                  '${index + 1}分钟前',
                  style: theme.textTheme.bodyMedium,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
