import 'package:flutter/material.dart';
import '../../../../apps/data/airports_database.dart';
import '../../../../apps/models/airport_detail_data.dart';
import '../../../../apps/services/weather_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../home/widgets/metar_display_widget.dart';
import '../../home/widgets/wind_direction_indicator.dart';

/// 通用的机场详情展示组件，可在不同页面复用
class AirportDetailView extends StatelessWidget {
  final AirportInfo airport;
  final MetarData? metar;
  final String? metarError;
  final AirportDetailData? detail;
  final String? detailError;
  final bool isLoading;
  final bool showWindIndicator;
  final VoidCallback? onRefreshMetar;

  const AirportDetailView({
    super.key,
    required this.airport,
    this.metar,
    this.metarError,
    this.detail,
    this.detailError,
    this.isLoading = false,
    this.showWindIndicator = true,
    this.onRefreshMetar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 优先使用详情中的高精度坐标
    final lat = detail?.latitude ?? airport.latitude;
    final lon = detail?.longitude ?? airport.longitude;
    final elev = detail?.elevation;

    // 处理风向风速
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showWindIndicator) ...[
              // 侧边风向标
              WindDirectionIndicator(
                windDirection: windDir,
                windSpeed: windSpeed,
                size: 140,
              ),
              const SizedBox(width: AppThemeData.spacingLarge),
            ],
            // 右侧主要垂直空间：坐标 + 气象 + 跑道
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCoords(theme, lat, lon, elev, isLoading: isLoading),
                  const SizedBox(height: 8),
                  _buildMetarSection(theme),
                  if (detail != null) ...[
                    const SizedBox(height: AppThemeData.spacingMedium),
                    _RunwaysSection(runways: detail!.runways),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (detail != null) ...[
          const SizedBox(height: AppThemeData.spacingMedium),
          Divider(color: AppThemeData.getBorderColor(theme), height: 1),
          const SizedBox(height: AppThemeData.spacingMedium),
          _FrequenciesSection(frequencies: detail!.frequencies),
          if (detail!.navaids.isNotEmpty) ...[
            const SizedBox(height: AppThemeData.spacingMedium),
            _NavaidsSection(navaids: detail!.navaids),
          ],
        ] else if (detailError != null) ...[
          const SizedBox(height: AppThemeData.spacingMedium),
          _buildErrorTip(theme, detailError!),
        ],
      ],
    );
  }

  Widget _buildCoords(
    ThemeData theme,
    double lat,
    double lon,
    int? elev, {
    bool isLoading = false,
  }) {
    final hasCoords = lat != 0.0 || lon != 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(icon: Icons.explore_outlined, label: '位置与坐标'),
        const SizedBox(height: 6),
        if (!hasCoords && isLoading)
          const Text(
            '正在获取位置数据...',
            style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'LAT: ${hasCoords ? lat.toStringAsFixed(6) : "Unknown"}°',
                style: TextStyle(
                  fontSize: 10,
                  color: hasCoords ? Colors.grey : theme.colorScheme.error,
                  fontWeight: hasCoords ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              Text(
                'LON: ${hasCoords ? lon.toStringAsFixed(6) : "Unknown"}°',
                style: TextStyle(
                  fontSize: 10,
                  color: hasCoords ? Colors.grey : theme.colorScheme.error,
                  fontWeight: hasCoords ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              if (elev != null)
                Text(
                  'ELEV: $elev ft',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildMetarSection(ThemeData theme) {
    if (metarError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: Text(
          '气象获取失败: $metarError',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.red.shade800,
          ),
        ),
      );
    }

    if (metar != null) {
      return MetarDisplayWidget(
        airportLabel: '最新气象快照',
        metarData: metar!,
        compact: true,
        icon: Icons.wb_sunny_outlined,
        onRefresh: onRefreshMetar,
        isRefreshing: isLoading,
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: isLoading
          ? const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('加载气象中...', style: TextStyle(fontSize: 12)),
              ],
            )
          : const Text(
              '暂无气象报文',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ],
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
        const _SectionHeader(icon: Icons.flight_land, label: '跑道详情'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rw.ident,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (rw.leIls != null || rw.heIls != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.settings_input_antenna,
                  size: 10,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
          Text(
            '${rw.lengthFt ?? "N/A"} ft / ${rw.surfaceDisplay}',
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 8),
          ),
          if (rw.leIls != null)
            Text(
              '${rw.leIdent} ILS: ${rw.leIls!.freq}MHz',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 8,
                color: theme.colorScheme.primary,
              ),
            ),
          if (rw.heIls != null)
            Text(
              '${rw.heIdent} ILS: ${rw.heIls!.freq}MHz',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 8,
                color: theme.colorScheme.primary,
              ),
            ),
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
        const _SectionHeader(icon: Icons.radio, label: '通信频率'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: frequencies.all
              .take(8)
              .map((f) => _FreqChip(f: f))
              .toList(),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${f.typeDisplay}: ${f.displayFrequency} MHz',
        style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
      ),
    );
  }
}

class _NavaidsSection extends StatelessWidget {
  final List<NavaidInfo> navaids;
  const _NavaidsSection({required this.navaids});

  @override
  Widget build(BuildContext context) {
    if (navaids.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(icon: Icons.navigation_rounded, label: '导航台'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: navaids.take(6).map((n) => _NavaidChip(n: n)).toList(),
        ),
      ],
    );
  }
}

class _NavaidChip extends StatelessWidget {
  final NavaidInfo n;
  const _NavaidChip({required this.n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = n.type.toUpperCase();
    final isNdb = type.contains('NDB');
    final unit = isNdb ? 'kHz' : 'MHz';
    final freqDisplay = isNdb
        ? n.frequency.toStringAsFixed(0)
        : n.frequency.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${n.ident} ($type): $freqDisplay $unit',
        style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
      ),
    );
  }
}
