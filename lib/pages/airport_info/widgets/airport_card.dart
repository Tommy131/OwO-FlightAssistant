import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../apps/data/airports_database.dart';
import '../../../../apps/models/airport_detail_data.dart';
import '../../../apps/providers/simulator/simulator_provider.dart';
import '../../../../apps/services/weather_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../home/widgets/metar_display_widget.dart';
import '../../home/widgets/wind_direction_indicator.dart';

class AirportCard extends StatefulWidget {
  final AirportInfo airport;
  final MetarData? metar; // 实时气象
  final String? metarError;
  final AirportDetailData? detail; // 本地数据库数据
  final AirportDetailData? onlineDetail; // 在线API数据
  final String? detailError;
  final bool isSaved;
  final bool isLoading;
  final VoidCallback onSave;
  final VoidCallback onRemove;
  final VoidCallback onRefreshDetail;
  final VoidCallback onOnlineFetch;

  const AirportCard({
    super.key,
    required this.airport,
    this.metar,
    this.metarError,
    this.detail,
    this.onlineDetail,
    this.detailError,
    required this.isSaved,
    required this.isLoading,
    required this.onSave,
    required this.onRemove,
    required this.onRefreshDetail,
    required this.onOnlineFetch,
  });

  @override
  State<AirportCard> createState() => _AirportCardState();
}

class _AirportCardState extends State<AirportCard> {
  bool _showOnline = false;

  @override
  void initState() {
    super.initState();
    // 默认显示在线数据（如果本地数据缺失但在线数据存在）
    _showOnline = widget.onlineDetail != null && widget.detail == null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final simProvider = context.watch<SimulatorProvider>();

    bool isNearest =
        simProvider.nearestAirport?.icaoCode == widget.airport.icaoCode;
    bool isDest =
        simProvider.destinationAirport?.icaoCode == widget.airport.icaoCode;
    bool isAlt =
        simProvider.alternateAirport?.icaoCode == widget.airport.icaoCode;
    bool isSimRelated =
        (isNearest || isDest || isAlt) && simProvider.isConnected;

    // 确定当前显示的详情数据
    final currentDetail = (_showOnline && widget.onlineDetail != null)
        ? widget.onlineDetail
        : widget.detail;

    // 优先使用当前详情抓取的缓存气象，否则回退到即时刷新气象
    final displayMetar = currentDetail?.metar ?? widget.metar;

    double? windDir;
    double? windSpeed;
    if (displayMetar?.wind != null) {
      try {
        final windStr = displayMetar!.wind!;
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
          _buildHeader(theme, isSimRelated, isNearest, isDest, isAlt),
          const SizedBox(height: AppThemeData.spacingMedium),
          Divider(color: AppThemeData.getBorderColor(theme), height: 1),
          const SizedBox(height: AppThemeData.spacingMedium),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 侧边风向标
              WindDirectionIndicator(
                windDirection: windDir,
                windSpeed: windSpeed,
                size: 140,
              ),
              const SizedBox(width: AppThemeData.spacingLarge),
              // 右侧主要垂直空间：气象 + 跑道
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCoords(),
                    const SizedBox(height: 8),
                    _buildMetarSection(theme, displayMetar),
                    if (currentDetail != null) ...[
                      const SizedBox(height: AppThemeData.spacingMedium),
                      _RunwaysSection(runways: currentDetail.runways),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (currentDetail != null) ...[
            const SizedBox(height: AppThemeData.spacingMedium),
            Divider(color: AppThemeData.getBorderColor(theme), height: 1),
            const SizedBox(height: AppThemeData.spacingMedium),
            _FrequenciesSection(frequencies: currentDetail.frequencies),
            if (currentDetail.navaids.isNotEmpty) ...[
              const SizedBox(height: AppThemeData.spacingMedium),
              _NavaidsSection(navaids: currentDetail.navaids),
            ],
          ] else if (widget.detailError != null) ...[
            const SizedBox(height: AppThemeData.spacingMedium),
            _buildErrorTip(theme, widget.detailError!),
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
  ) {
    // 确定当前显示的详情数据
    final currentDetail = (_showOnline && widget.onlineDetail != null)
        ? widget.onlineDetail
        : widget.detail;

    return Row(
      children: [
        Icon(
          isSimRelated
              ? (isNearest
                    ? Icons.my_location
                    : (isDest ? Icons.flag : Icons.alt_route))
              : Icons.location_on,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${widget.airport.icaoCode} ',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      widget.airport.nameChinese,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSimRelated) ...[
                    const SizedBox(width: 6),
                    _SimBadge(
                      label: isNearest ? '当前' : (isDest ? '目的地' : '备降'),
                    ),
                  ],
                  // 机场名称右侧显示当前展示的数据库名称
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      currentDetail?.dataSourceDisplay ??
                          ((_showOnline && widget.onlineDetail != null)
                              ? '在线 API'
                              : '本地数据库'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              // 副标题显示上次更新时间（本地和在线分别显示）
              const SizedBox(height: 2),
              Row(
                children: [
                  _buildUpdateTimeBadge(
                    theme,
                    label: '本地',
                    time: widget.detail?.dataAge ?? '无',
                    active: !_showOnline,
                  ),
                  const SizedBox(width: 8),
                  _buildUpdateTimeBadge(
                    theme,
                    label: '在线',
                    time: widget.onlineDetail?.dataAge ?? '无',
                    active: _showOnline,
                  ),
                ],
              ),
            ],
          ),
        ),

        // 右侧按钮组：本地刷新 | 在线获取 | 切换滑块 | 移除/保存
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.detail != null && widget.onlineDetail != null)
              _buildToggleSwitcher(theme),
            const SizedBox(width: 4),
            IconButton(
              onPressed: widget.onRefreshDetail,
              icon: const Icon(Icons.refresh, size: 20),
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
              tooltip: '更新本地缓存',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: widget.onOnlineFetch,
              icon: const Icon(Icons.language, size: 20),
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
              tooltip: '通过在线 API 更新',
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            widget.isSaved
                ? IconButton(
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.delete_outline, size: 22),
                    color: theme.colorScheme.error.withValues(alpha: 0.7),
                    tooltip: '从列表移除',
                    visualDensity: VisualDensity.compact,
                  )
                : IconButton(
                    onPressed: widget.onSave,
                    icon: const Icon(Icons.bookmark_add_outlined, size: 22),
                    color: theme.colorScheme.primary,
                    tooltip: '保存到列表',
                    visualDensity: VisualDensity.compact,
                  ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpdateTimeBadge(
    ThemeData theme, {
    required String label,
    required String time,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(
          color: active
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $time',
        style: theme.textTheme.labelSmall?.copyWith(
          color: active ? theme.colorScheme.primary : theme.colorScheme.outline,
          fontSize: 9,
        ),
      ),
    );
  }

  Widget _buildToggleSwitcher(ThemeData theme) {
    return Container(
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleItem(
            theme,
            label: '本地',
            isSelected: !_showOnline,
            onTap: () => setState(() => _showOnline = false),
          ),
          _buildToggleItem(
            theme,
            label: '在线',
            isSelected: _showOnline,
            onTap: () => setState(() => _showOnline = true),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(
    ThemeData theme, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 9,
          ),
        ),
      ),
    );
  }

  Widget _buildMetarSection(ThemeData theme, MetarData? displayMetar) {
    if (widget.metarError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: Text(
          '气象获取失败: ${widget.metarError}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.red.shade800,
          ),
        ),
      );
    }

    if (displayMetar != null) {
      return MetarDisplayWidget(
        airportLabel: '最新气象快照',
        metarData: displayMetar,
        compact: true, // 开启紧凑模式以适应右侧列
        icon: Icons.wb_sunny_outlined,
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: widget.isLoading && displayMetar == null
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

  Widget _buildCoords() {
    // 优先使用详情中的高精度坐标
    final currentDetail = (_showOnline && widget.onlineDetail != null)
        ? widget.onlineDetail
        : widget.detail;
    final lat = currentDetail?.latitude ?? widget.airport.latitude;
    final lon = currentDetail?.longitude ?? widget.airport.longitude;
    final elev = currentDetail?.elevation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(icon: Icons.explore_outlined, label: '位置与坐标'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              'LAT: ${lat.toStringAsFixed(6)}°',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              'LON: ${lon.toStringAsFixed(6)}°',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
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
}

class _SimBadge extends StatelessWidget {
  final String label;
  const _SimBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
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
        _SectionHeader(icon: Icons.flight_land, label: '跑道详情'),
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
        _SectionHeader(icon: Icons.radio, label: '通信频率'),
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
        _SectionHeader(icon: Icons.navigation_rounded, label: '导航台'),
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
