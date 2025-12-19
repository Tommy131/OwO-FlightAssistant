import 'package:flutter/material.dart';

import '../../core/theme/app_theme_data.dart';

/// 探索页面示例
class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: CustomScrollView(
        slivers: [
          // 顶部分类标签
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(AppThemeData.spacingMedium),
              color: theme.colorScheme.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip(theme, '全部', true),
                    _buildCategoryChip(theme, '科技', false),
                    _buildCategoryChip(theme, '设计', false),
                    _buildCategoryChip(theme, '开发', false),
                    _buildCategoryChip(theme, '商业', false),
                    _buildCategoryChip(theme, '艺术', false),
                  ],
                ),
              ),
            ),
          ),

          // 内容网格
          SliverPadding(
            padding: const EdgeInsets.all(AppThemeData.spacingMedium),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                mainAxisSpacing: AppThemeData.spacingMedium,
                crossAxisSpacing: AppThemeData.spacingMedium,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                return _buildContentCard(theme, index);
              }, childCount: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(ThemeData theme, String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: AppThemeData.spacingSmall),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          // TODO: 处理分类选择
        },
        backgroundColor: theme.scaffoldBackgroundColor,
        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
        checkmarkColor: theme.colorScheme.primary,
        labelStyle: TextStyle(
          color: isSelected
              ? theme.colorScheme.primary
              : AppThemeData.getTextColor(theme),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : AppThemeData.getBorderColor(theme),
        ),
      ),
    );
  }

  Widget _buildContentCard(ThemeData theme, int index) {
    return Container(
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
        children: [
          // 图片占位
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.6),
                  theme.colorScheme.secondary.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppThemeData.borderRadiusMedium),
                topRight: Radius.circular(AppThemeData.borderRadiusMedium),
              ),
            ),
            child: Center(
              child: Icon(
                Icons.image,
                size: 48,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),

          // 内容信息
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppThemeData.spacingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '内容标题 ${index + 1}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppThemeData.spacingSmall),
                  Text(
                    '这是内容的描述文本，展示更多详细信息...',
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 16,
                        color: AppThemeData.getTextColor(
                          theme,
                          isPrimary: false,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(index + 1) * 123}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: AppThemeData.spacingMedium),
                      Icon(
                        Icons.comment_outlined,
                        size: 16,
                        color: AppThemeData.getTextColor(
                          theme,
                          isPrimary: false,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(index + 1) * 45}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
