import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../apps/services/airport_detail_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../home/widgets/airport_search_bar.dart';
import '../providers/airport_info_provider.dart';

class AirportInfoHeader extends StatelessWidget {
  final VoidCallback onRefresh;

  const AirportInfoHeader({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AirportInfoProvider>();

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '机场信息',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _buildDataSourcePicker(context, theme, provider),
              const SizedBox(width: 8),
              IconButton(
                onPressed: provider.isLoading ? null : onRefresh,
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: '刷新数据',
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingMedium),
          Row(
            children: [
              Expanded(
                child: AirportSearchBar(
                  hintText: '搜索机场 (ICAO/IATA/名称/经纬度)...',
                  onSelect: (airport) {
                    provider.saveAirport(airport);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataSourcePicker(
    BuildContext context,
    ThemeData theme,
    AirportInfoProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storage, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          DropdownButton<AirportDataSource>(
            value: provider.currentDataSource,
            underline: const SizedBox(),
            isDense: true,
            style: theme.textTheme.bodySmall,
            onChanged: (source) {
              if (source != null && source != provider.currentDataSource) {
                provider.switchDataSource(source);
              }
            },
            items: AirportDataSource.values
                .where((s) => s != AirportDataSource.aviationApi)
                .map((source) {
                  final isAvailable = provider.availableDataSources.contains(
                    source,
                  );
                  return DropdownMenuItem(
                    value: source,
                    enabled: isAvailable,
                    child: Row(
                      children: [
                        Text(
                          source.displayName,
                          style: TextStyle(
                            color: isAvailable ? null : theme.disabledColor,
                          ),
                        ),
                        if (!isAvailable) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.lock_outline,
                            size: 12,
                            color: theme.disabledColor,
                          ),
                        ],
                      ],
                    ),
                  );
                })
                .toList(),
          ),
        ],
      ),
    );
  }
}
