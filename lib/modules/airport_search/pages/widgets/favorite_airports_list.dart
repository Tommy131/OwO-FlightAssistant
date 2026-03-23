import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/airport_search_localization_keys.dart';
import '../../models/airport_search_models.dart';

/// 收藏机场列表组件
/// 显示用户已收藏的所有机场条目，并支持点击直接跳转查询
class FavoriteAirportsList extends StatelessWidget {
  /// 收藏条目数据列表
  final List<FavoriteAirportEntry> favorites;

  /// 点击打开/搜索某个收藏机场的回调 (传入 ICAO)
  final void Function(String icao) onOpen;

  const FavoriteAirportsList({
    super.key,
    required this.favorites,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: AppThemeData.getBorderColor(theme).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 列表标题
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 20, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                AirportSearchLocalizationKeys.favoritesTitle.tr(context),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingSmall),

          // 空列表占位
          if (favorites.isEmpty)
            Text(
              AirportSearchLocalizationKeys.favoritesEmpty.tr(context),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            )
          // 列表项遍历
          else
            ...favorites.map((entry) => _buildFavoriteItem(context, entry)),
        ],
      ),
    );
  }

  /// 构建单个收藏项的 Widget
  Widget _buildFavoriteItem(BuildContext context, FavoriteAirportEntry entry) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppThemeData.spacingSmall),
      padding: const EdgeInsets.all(AppThemeData.spacingSmall),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.25,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.flight, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 机场标识 (ICAO · 名称)
                Text(
                  '${entry.icao} · ${entry.name ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // 经纬度摘要
                Text(
                  '${AirportSearchLocalizationKeys.airportLatLonLabel.tr(context)}: '
                  '${entry.latitude?.toStringAsFixed(4) ?? '-'}, '
                  '${entry.longitude?.toStringAsFixed(4) ?? '-'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // 快速查询按钮
          TextButton(
            onPressed: () => onOpen(entry.icao),
            child: Text(AirportSearchLocalizationKeys.searchButton.tr(context)),
          ),
        ],
      ),
    );
  }
}
