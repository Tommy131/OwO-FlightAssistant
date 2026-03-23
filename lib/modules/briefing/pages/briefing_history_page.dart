import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/localization_keys.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/snack_bar.dart';
import '../../../core/widgets/common/dialog.dart';
import '../localization/briefing_localization_keys.dart';
import '../models/briefing_record.dart';
import '../providers/briefing_provider.dart';

/// 飞行简报历史记录展示页面
/// 支持查看历史简报详情、刷新同步本地文件以及删除失效记录
class BriefingHistoryPage extends StatefulWidget {
  final VoidCallback onBack;

  const BriefingHistoryPage({super.key, required this.onBack});

  @override
  State<BriefingHistoryPage> createState() => _BriefingHistoryPageState();
}

class _BriefingHistoryPageState extends State<BriefingHistoryPage> {
  /// 存储当前处于展开状态的记录 ID (以实现局部详情预览)
  final Set<String> _expandedRecordIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(BriefingLocalizationKeys.historyTitle.tr(context)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
        actions: [
          // 刷新按钮：重新扫描本地存储目录
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: BriefingLocalizationKeys.refresh.tr(context),
            onPressed: () => _handleRefresh(context),
          ),
          const SizedBox(width: AppThemeData.spacingMedium),
        ],
      ),
      body: Consumer<BriefingProvider>(
        builder: (context, provider, child) {
          if (provider.history.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppThemeData.spacingMedium),
            itemCount: provider.history.length,
            itemBuilder: (context, index) {
              final record = provider.history[index];
              return _buildHistoryCard(context, record);
            },
          );
        },
      ),
    );
  }

  /// 构建空列表占位视图
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 48,
            color: theme.hintColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            BriefingLocalizationKeys.historyEmpty.tr(context),
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  /// 构建单条历史记录卡片
  Widget _buildHistoryCard(BuildContext context, BriefingRecord record) {
    final theme = Theme.of(context);
    final recordId =
        '${record.createdAt.millisecondsSinceEpoch}-${record.title}';
    final isExpanded = _expandedRecordIds.contains(recordId);
    final summary = _buildSummaryText(record);

    return Card(
      margin: const EdgeInsets.only(bottom: AppThemeData.spacingSmall),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedRecordIds.remove(recordId);
            } else {
              _expandedRecordIds.add(recordId);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(AppThemeData.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部标题及删除操作区
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildDeleteButton(context, record, recordId),
                ],
              ),
              const SizedBox(height: 4),
              // 概要信息展示 (航班号 & 时间)
              Text(
                summary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),

              // 展开后的完整内容展示区域
              if (isExpanded) ...[
                const Divider(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppThemeData.spacingSmall),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    record.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'RobotoMono', // 使用等宽字体展示简报正文
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 处理刷新同步逻辑
  Future<void> _handleRefresh(BuildContext context) async {
    final provider = context.read<BriefingProvider>();
    try {
      final count = await provider.reloadFromDirectory();
      if (!context.mounted) return;
      if (count > 0) {
        final msg = BriefingLocalizationKeys.refreshSuccess
            .tr(context)
            .replaceAll('{}', count.toString());
        SnackBarHelper.showSuccess(context, msg);
      } else {
        SnackBarHelper.showWarning(
          context,
          BriefingLocalizationKeys.refreshEmpty.tr(context),
        );
      }
    } catch (_) {
      if (context.mounted) {
        SnackBarHelper.showError(
          context,
          BriefingLocalizationKeys.refreshFailed.tr(context),
        );
      }
    }
  }

  /// 构建删除按钮并绑定二次确认弹窗
  Widget _buildDeleteButton(
    BuildContext context,
    BriefingRecord record,
    String recordId,
  ) {
    return IconButton(
      tooltip: BriefingLocalizationKeys.deleteAction.tr(context),
      visualDensity: VisualDensity.compact,
      onPressed: () async {
        final confirmed = await showAdvancedConfirmDialog(
          context: context,
          title: BriefingLocalizationKeys.deleteConfirmTitle.tr(context),
          content: BriefingLocalizationKeys.deleteConfirmContent.tr(context),
          icon: Icons.delete_outline,
          confirmColor: Colors.redAccent,
          confirmText: LocalizationKeys.confirm.tr(context),
          cancelText: LocalizationKeys.cancel.tr(context),
        );

        if (confirmed == true && context.mounted) {
          final ok = await context.read<BriefingProvider>().deleteBriefing(
            record,
          );
          if (ok && context.mounted) {
            setState(() => _expandedRecordIds.remove(recordId));
            SnackBarHelper.showSuccess(
              context,
              BriefingLocalizationKeys.deleteSuccess.tr(context),
            );
          }
        }
      },
      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
    );
  }

  /// 提取简报正文中的关键信息用于卡片摘要显示
  String _buildSummaryText(BriefingRecord record) {
    final lines = record.content.split('\n');
    String flt = '--';
    String gen = record.createdAt.toLocal().toString();
    for (final line in lines) {
      if (!line.contains(':')) continue;
      final k = line.split(':').first.trim();
      final v = line.split(':').last.trim();
      if (k == 'FLT' && v.isNotEmpty) {
        flt = v;
      } else if (k == 'GEN' && v.isNotEmpty) {
        gen = v;
      }
    }
    return '✈ $flt  ·  🕒 $gen';
  }
}
