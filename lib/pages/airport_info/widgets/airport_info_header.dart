import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../apps/models/airport_detail_data.dart';
import '../../../apps/services/airport_detail_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/dialog.dart';
import '../../home/widgets/airport_search_bar.dart';
import '../providers/airport_info_provider.dart';
import 'airport_list.dart';

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
            onChanged: (source) async {
              if (source != null && source != provider.currentDataSource) {
                final previousDetails = Map<String, AirportDetailData>.from(
                  provider.airportDetails,
                );
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('正在切换数据源...'),
                            SizedBox(height: 8),
                            Text(
                              '可能需要几秒钟，请勿关闭应用',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                try {
                  await provider.switchDataSource(source);
                } finally {
                  if (context.mounted) Navigator.pop(context);
                }
                if (context.mounted) {
                  await _compareLocalDataChanges(
                    context,
                    provider,
                    source,
                    previousDetails,
                  );
                }
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

  Future<void> _compareLocalDataChanges(
    BuildContext context,
    AirportInfoProvider provider,
    AirportDataSource source,
    Map<String, AirportDetailData> previousDetails,
  ) async {
    final airports = provider.savedAirports;
    if (airports.isEmpty || previousDetails.isEmpty) return;

    showLoadingDialog(context: context, message: '正在比对新旧机场数据...');
    final freshDetails = <String, AirportDetailData>{};
    for (final airport in airports) {
      final fresh = await provider.fetchLocalDetail(
        airport.icaoCode,
        forceRefresh: true,
        source: source,
      );
      if (fresh != null) {
        freshDetails[airport.icaoCode] = fresh;
      }
    }
    if (context.mounted) {
      hideLoadingDialog(context);
    }

    bool updateAll = false;
    bool skipAll = false;
    for (final airport in airports) {
      final fresh = freshDetails[airport.icaoCode];
      if (fresh == null) continue;
      final existing = previousDetails[airport.icaoCode];
      if (existing == null || !existing.hasSignificantDifference(fresh)) {
        provider.applyUpdate(airport, fresh);
        continue;
      }
      if (updateAll) {
        provider.applyUpdate(airport, fresh);
        continue;
      }
      if (skipAll) {
        continue;
      }
      final userChoice = await showAirportUpdateConfirmationDialog(
        context,
        airport,
        existing,
        fresh,
      );
      if (userChoice == 'new') {
        provider.applyUpdate(airport, fresh);
      } else if (userChoice == 'all_new') {
        updateAll = true;
        provider.applyUpdate(airport, fresh);
      } else if (userChoice == 'all_skip') {
        skipAll = true;
      } else if (userChoice == 'old') {
        provider.applyUpdate(airport, existing);
      }
    }
  }
}
