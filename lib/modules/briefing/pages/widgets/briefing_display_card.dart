import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/briefing_localization_keys.dart';
import '../../providers/briefing_provider.dart';

/// 飞行简报预览展示卡片
/// 负责实时显示生成的简报内容，并提供快捷复制功能。
class BriefingDisplayCard extends StatelessWidget {
  const BriefingDisplayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<BriefingProvider>(
      builder: (context, provider, child) {
        final latest = provider.latest;
        final content = latest?.content ?? '';

        return Container(
          padding: const EdgeInsets.all(AppThemeData.spacingMedium),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部渐变标题栏与复制按钮
              _buildHeader(
                context,
                title: BriefingLocalizationKeys.outputTitle.tr(context),
                routeText: latest?.title ?? '--',
                contentToCopy: content,
              ),
              const SizedBox(height: AppThemeData.spacingMedium),

              // 内容展示区域
              if (provider.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (latest == null)
                _buildEmptyPlaceholder(context)
              else
                _buildBriefingBody(context, content),
            ],
          ),
        );
      },
    );
  }

  /// 构建空状态提示
  Widget _buildEmptyPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: theme.hintColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              BriefingLocalizationKeys.outputEmpty.tr(context),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建层级清晰的简报内容主体
  Widget _buildBriefingBody(BuildContext context, String content) {
    final theme = Theme.of(context);
    final lines = content
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: lines.map((line) => _buildContentRow(context, line)).toList(),
      ),
    );
  }

  /// 顶部渐变标题头组件
  Widget _buildHeader(
    BuildContext context, {
    required String title,
    required String routeText,
    required String contentToCopy,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
      ),
      child: Row(
        children: [
          const Icon(Icons.description, color: Colors.white, size: 24),
          const SizedBox(width: AppThemeData.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  routeText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          // 复制到剪贴板
          IconButton(
            onPressed: contentToCopy.trim().isEmpty
                ? null
                : () => _copyToClipboard(context, contentToCopy),
            icon: const Icon(Icons.copy_all_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// 单行 Key: Value 格式解析显示
  Widget _buildContentRow(BuildContext context, String line) {
    final theme = Theme.of(context);
    final parts = line.split(':');
    if (parts.length < 2) return Text(line, style: theme.textTheme.bodyMedium);

    final label = parts.first.trim();
    final value = parts.sublist(1).join(':').trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'MonoSpace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(BriefingLocalizationKeys.copySuccess.tr(context)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
