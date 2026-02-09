import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../apps/providers/briefing_provider.dart';
import '../../../apps/models/flight_briefing.dart';
import '../../../core/theme/app_theme_data.dart';
import 'briefing_display_card.dart';

/// 历史简报页面
class BriefingHistoryPage extends StatelessWidget {
  final VoidCallback onBack;

  const BriefingHistoryPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<BriefingProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(AppThemeData.spacingMedium),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: theme.dividerColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Text(
                  '历史简报',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (provider.briefingHistory.isNotEmpty)
                  TextButton.icon(
                    onPressed: () =>
                        _showClearAllConfirmDialog(context, provider),
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('清除全部'),
                  ),
              ],
            ),
          ),
          // 内容区域
          Expanded(
            child: provider.briefingHistory.isEmpty
                ? _buildEmptyState(theme)
                : Row(
                    children: [
                      // 左侧：历史列表
                      SizedBox(
                        width: 380,
                        child: _buildHistoryList(context, theme, provider),
                      ),

                      // 分隔线
                      VerticalDivider(width: 1, color: theme.dividerColor),

                      // 右侧：简报详情
                      Expanded(
                        child: provider.currentBriefing != null
                            ? BriefingDisplayCard(
                                briefing: provider.currentBriefing!,
                              )
                            : _buildSelectHint(theme),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(
    BuildContext context,
    ThemeData theme,
    BriefingProvider provider,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      itemCount: provider.briefingHistory.length,
      itemBuilder: (context, index) {
        final briefing = provider.briefingHistory[index];
        final isSelected = provider.currentBriefing == briefing;

        return Card(
          margin: const EdgeInsets.only(bottom: AppThemeData.spacingSmall),
          elevation: isSelected ? 4 : 1,
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          child: InkWell(
            onTap: () => provider.loadBriefingFromHistory(index),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(AppThemeData.spacingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.description,
                          color: isSelected
                              ? Colors.white
                              : theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppThemeData.spacingSmall),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              briefing.formattedFlightNumber,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${briefing.departureAirport.icaoCode} → ${briefing.arrivalAirport.icaoCode}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 删除按钮
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _showDeleteConfirmDialog(
                          context,
                          provider,
                          index,
                          briefing,
                        ),
                        tooltip: '删除此简报',
                        color: theme.colorScheme.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppThemeData.spacingSmall),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.7,
                              )
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        briefing.formattedGeneratedTime,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer.withValues(
                                  alpha: 0.7,
                                )
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                      ),
                      const Spacer(),
                      if (briefing.distance != null) ...[
                        Icon(
                          Icons.straighten,
                          size: 14,
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer.withValues(
                                  alpha: 0.7,
                                )
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${briefing.distance!.toStringAsFixed(0)} NM',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? theme.colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.7)
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppThemeData.spacingLarge),
          Text(
            '暂无历史记录',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppThemeData.spacingSmall),
          Text(
            '生成的简报会自动保存在这里',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectHint(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app,
            size: 60,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          Text(
            '请选择一条历史记录',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    BriefingProvider provider,
    int index,
    FlightBriefing briefing,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除简报'),
        content: Text(
          '确定要删除简报 ${briefing.formattedFlightNumber} 吗？\n'
          '${briefing.departureAirport.icaoCode} → ${briefing.arrivalAirport.icaoCode}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              provider.deleteBriefing(index);
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('✅ 简报已删除')));
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showClearAllConfirmDialog(
    BuildContext context,
    BriefingProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除所有历史记录'),
        content: const Text('确定要清除所有历史简报吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('清除全部'),
          ),
        ],
      ),
    );
  }
}
