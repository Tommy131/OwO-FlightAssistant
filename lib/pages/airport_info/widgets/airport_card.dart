import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../apps/data/airports_database.dart';
import '../../../../apps/models/airport_detail_data.dart';
import '../../../apps/providers/simulator/simulator_provider.dart';
import '../../../../apps/services/weather_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../home/widgets/flight_data_widgets.dart';
import '../../home/widgets/metar_display_widget.dart';
import '../../home/widgets/wind_direction_indicator.dart';

class AirportCard extends StatelessWidget {
  final AirportInfo airport;
  final MetarData? metar;
  final String? metarError;
  final AirportDetailData? detail;
  final String? detailError;
  final bool isSaved;
  final bool isLoading;
  final VoidCallback onSave;
  final VoidCallback onRemove;
  final VoidCallback onRefreshDetail;
  final String currentDataSourceName;

  const AirportCard({
    super.key,
    required this.airport,
    this.metar,
    this.metarError,
    this.detail,
    this.detailError,
    required this.isSaved,
    required this.isLoading,
    required this.onSave,
    required this.onRemove,
    required this.onRefreshDetail,
    required this.currentDataSourceName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final simProvider = context.watch<SimulatorProvider>();

    bool isNearest = simProvider.nearestAirport?.icaoCode == airport.icaoCode;
    bool isDest = simProvider.destinationAirport?.icaoCode == airport.icaoCode;
    bool isAlt = simProvider.alternateAirport?.icaoCode == airport.icaoCode;
    bool isSimRelated =
        (isNearest || isDest || isAlt) && simProvider.isConnected;

    double? windDir;
    double? windSpeed;
    if (metar?.wind != null) {
      try {
        final windStr = metar!.wind!;
        if (windStr.length >= 5) {
          windDir = double.tryParse(windStr.substring(0, 3));
          windSpeed = double.tryParse(
            windStr.substring(3).replaceAll(RegExp(r'[^0-9]'), ''),
          );
        }
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: isSimRelated
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : AppThemeData.getBorderColor(theme),
          width: isSimRelated ? 2 : 1,
        ),
        gradient: isSimRelated
            ? LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
                  theme.colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, isSimRelated, isNearest, isDest, isAlt, isSaved),
          const SizedBox(height: AppThemeData.spacingMedium),
          _buildCoords(),
          const SizedBox(height: AppThemeData.spacingMedium),
          Divider(color: AppThemeData.getBorderColor(theme)),
          const SizedBox(height: AppThemeData.spacingMedium),
          _buildMetarRow(theme, windDir, windSpeed),
          if (detail != null) ...[
            const SizedBox(height: AppThemeData.spacingMedium),
            Divider(color: AppThemeData.getBorderColor(theme)),
            const SizedBox(height: AppThemeData.spacingMedium),
            _buildDetailedInfo(theme),
          ] else if (detailError != null) ...[
            const SizedBox(height: AppThemeData.spacingMedium),
            _buildErrorTip(theme, detailError!),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    bool isSimRelated,
    bool isNearest,
    bool isDest,
    bool isAlt,
    bool isSaved,
  ) {
    return Row(
      children: [
        if (isSimRelated)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isNearest
                  ? Icons.my_location
                  : (isDest ? Icons.flag : Icons.alt_route),
              color: theme.colorScheme.onPrimary,
              size: 16,
            ),
          )
        else
          Icon(Icons.location_on, color: theme.colorScheme.primary, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      airport.displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSimRelated) ...[
                    const SizedBox(width: 8),
                    _SimBadge(
                      label: isNearest ? '当前' : (isDest ? '目的地' : '备降'),
                    ),
                  ],
                ],
              ),
              Text(
                'ICAO: ${airport.icaoCode}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        if (!isSaved && isSimRelated)
          IconButton(
            onPressed: onSave,
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: '保存到我的列表',
            color: theme.colorScheme.primary,
          ),
        if (isSaved)
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
            tooltip: '从我的列表移除',
            color: theme.colorScheme.error.withValues(alpha: 0.7),
          ),
      ],
    );
  }

  Widget _buildCoords() {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        InfoChip(label: '纬度', value: airport.latitude.toStringAsFixed(4)),
        InfoChip(label: '经度', value: airport.longitude.toStringAsFixed(4)),
      ],
    );
  }

  Widget _buildMetarRow(ThemeData theme, double? windDir, double? windSpeed) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WindDirectionIndicator(
          windDirection: windDir,
          windSpeed: windSpeed,
          size: 140,
        ),
        const SizedBox(width: AppThemeData.spacingLarge),
        Expanded(child: _buildMetarSection(theme)),
      ],
    );
  }

  Widget _buildMetarSection(ThemeData theme) {
    if (metarError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Text(
                  '获取失败',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              metarError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    if (isLoading && metar == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('加载气象报文...'),
          ],
        ),
      );
    }

    if (metar != null) {
      return MetarDisplayWidget(
        airportLabel: '最新气象',
        metarData: metar!,
        compact: false,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: const Text('暂无气象数据', style: TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildDetailedInfo(ThemeData theme) {
    final d = detail!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: d.isCached
                  ? d.isExpired
                        ? [
                            Colors.orange.withValues(alpha: 0.1),
                            Colors.orange.withValues(alpha: 0.02),
                          ]
                        : [
                            Colors.blue.withValues(alpha: 0.1),
                            Colors.blue.withValues(alpha: 0.02),
                          ]
                  : [
                      Colors.green.withValues(alpha: 0.1),
                      Colors.green.withValues(alpha: 0.02),
                    ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: d.isCached
                  ? d.isExpired
                        ? Colors.orange.withValues(alpha: 0.3)
                        : Colors.blue.withValues(alpha: 0.3)
                  : Colors.green.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                d.isCached
                    ? (d.isExpired ? Icons.update : Icons.cached)
                    : Icons.cloud_done,
                color: d.isCached
                    ? (d.isExpired ? Colors.orange : Colors.blue)
                    : Colors.green,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.isCached
                          ? (d.isExpired ? '缓存已过期' : '使用缓存数据')
                          : '最新详细数据',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: d.isCached
                            ? (d.isExpired
                                  ? Colors.orange.shade800
                                  : Colors.blue.shade800)
                            : Colors.green.shade800,
                      ),
                    ),
                    Text(
                      '更新于: ${d.dataAge} | 数据源: $currentDataSourceName',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (d.isExpired || d.isMockData)
                IconButton(
                  onPressed: onRefreshDetail,
                  icon: const Icon(Icons.refresh),
                  color: Colors.orange,
                ),
            ],
          ),
        ),
        if (d.isMockData) _MockDataWarning(),
        _RunwaysSection(runways: d.runways),
        const SizedBox(height: AppThemeData.spacingMedium),
        _FrequenciesSection(frequencies: d.frequencies),
      ],
    );
  }

  Widget _buildErrorTip(ThemeData theme, String error) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimBadge extends StatelessWidget {
  final String label;
  const _SimBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MockDataWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.purple, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '提示: 当前显示内容为内置模拟数据，仅供演示！',
              style: TextStyle(
                fontSize: 12,
                color: Colors.purple.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunwaysSection extends StatelessWidget {
  final List<RunwayInfo> runways;
  const _RunwaysSection({required this.runways});

  @override
  Widget build(BuildContext context) {
    if (runways.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(icon: Icons.flight_land, label: '跑道信息'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: runways.map((rw) => _RunwayChip(rw: rw)).toList(),
        ),
      ],
    );
  }
}

class _RunwayChip extends StatelessWidget {
  final RunwayInfo rw;
  const _RunwayChip({required this.rw});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rw.ident,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          Text('${rw.lengthFt ?? "N/A"} ft', style: theme.textTheme.bodySmall),
          Text('表面: ${rw.surfaceDisplay}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _FrequenciesSection extends StatelessWidget {
  final AirportFrequencies frequencies;
  const _FrequenciesSection({required this.frequencies});

  @override
  Widget build(BuildContext context) {
    if (frequencies.all.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(icon: Icons.radio, label: '频率信息'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: frequencies.all.map((f) => _FreqChip(f: f)).toList(),
        ),
      ],
    );
  }
}

class _FreqChip extends StatelessWidget {
  final FrequencyInfo f;
  const _FreqChip({required this.f});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${f.typeDisplay}: ${f.displayFrequency} MHz',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
