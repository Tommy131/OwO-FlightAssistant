import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/airport_search_localization_keys.dart';
import '../../models/airport_search_models.dart';

/// ICAO 代码搜索输入组件
/// 包含大写强制转换、长度输入限制、实时建议列表展示功能
class IcaoSearchInput extends StatelessWidget {
  /// 输入控制器
  final TextEditingController controller;

  /// 是否正在进行核心查询
  final bool isBusy;

  /// 是否正在请求自动联想建议
  final bool isSuggesting;

  /// 自动联想生成的建议项列表
  final List<AirportSuggestionData> suggestions;

  /// 文本内容变化回调 (用于触发防抖建议请求)
  final ValueChanged<String> onChanged;

  /// 选中某个建议项后的回调 (通常联动填充并直接查询)
  final ValueChanged<AirportSuggestionData> onSelectSuggestion;

  /// 触发正式全量查询的回调 (点击搜索按钮或提交键盘)
  final VoidCallback onSearch;

  const IcaoSearchInput({
    super.key,
    required this.controller,
    required this.isBusy,
    required this.isSuggesting,
    required this.suggestions,
    required this.onChanged,
    required this.onSelectSuggestion,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        // 卡片渐变背景
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: AppThemeData.getBorderColor(theme).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签
          Text(
            AirportSearchLocalizationKeys.icaoLabel.tr(context),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppThemeData.spacingSmall),

          // 输入框
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            maxLength: 4,
            inputFormatters: [
              // 1. 仅限字母数字
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              // 2. 长度最大 4 位
              LengthLimitingTextInputFormatter(4),
              // 3. 实时强制转换为大写并维持光标位置
              TextInputFormatter.withFunction((oldValue, newValue) {
                return newValue.copyWith(
                  text: newValue.text.toUpperCase(),
                  selection: TextSelection.collapsed(
                    offset: newValue.text.length,
                  ),
                );
              }),
            ],
            decoration: InputDecoration(
              counterText: '',
              hintText: AirportSearchLocalizationKeys.icaoHint.tr(context),
              prefixIcon: const Icon(Icons.pin_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppThemeData.borderRadiusSmall,
                ),
              ),
            ),
            onChanged: onChanged, // 处理实时变化逻辑
            onSubmitted: (_) => onSearch(), // 模拟键盘搜索
          ),
          const SizedBox(height: 6),

          // 提示文本 (灰色小字)
          Text(
            '${AirportSearchLocalizationKeys.formatHint.tr(context)} · ${AirportSearchLocalizationKeys.fuzzyHint.tr(context)}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),

          // 如果有建议项或正在加载建议，则渲染建议列表面板
          if (isSuggesting || suggestions.isNotEmpty) ...[
            const SizedBox(height: AppThemeData.spacingSmall),
            _SuggestionList(
              isSuggesting: isSuggesting,
              suggestions: suggestions,
              onSelect: onSelectSuggestion,
            ),
          ],
          const SizedBox(height: AppThemeData.spacingSmall),

          // 搜索按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isBusy ? null : onSearch,
              icon: isBusy
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(
                AirportSearchLocalizationKeys.searchButton.tr(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 内部私有组件: 联想建议列表
class _SuggestionList extends StatelessWidget {
  final bool isSuggesting;
  final List<AirportSuggestionData> suggestions;
  final ValueChanged<AirportSuggestionData> onSelect;

  const _SuggestionList({
    required this.isSuggesting,
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AirportSearchLocalizationKeys.suggestionsTitle.tr(context),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),

            // 加载中状态显示 Loading
            if (isSuggesting)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            // 无结果提示
            else if (suggestions.isEmpty)
              Text(
                AirportSearchLocalizationKeys.suggestionsEmpty.tr(context),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              )
            // 展示搜索结果建议 Chip
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions
                    .map(
                      (item) => ActionChip(
                        onPressed: () => onSelect(item),
                        avatar: const Icon(Icons.flight_takeoff, size: 16),
                        label: Text(
                          '${item.icao} · ${item.name ?? '-'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
