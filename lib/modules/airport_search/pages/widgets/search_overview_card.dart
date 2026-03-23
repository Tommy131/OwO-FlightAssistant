import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/services/localization_service.dart';
import '../../localization/airport_search_localization_keys.dart';

/// 搜索概览卡片
/// 显示当前的搜索建议数量和收藏列表数量
class SearchOverviewCard extends StatelessWidget {
  /// 建议项数量
  final int suggestionCount;

  /// 收藏项数量
  final int favoritesCount;

  const SearchOverviewCard({
    super.key,
    required this.suggestionCount,
    required this.favoritesCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.16),
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
      ),
      child: Row(
        children: [
          const Icon(Icons.travel_explore_rounded, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${AirportSearchLocalizationKeys.suggestionsTitle.tr(context)}: $suggestionCount   '
              '${AirportSearchLocalizationKeys.favoritesTitle.tr(context)}: $favoritesCount',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
