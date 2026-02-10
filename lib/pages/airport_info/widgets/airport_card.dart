import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../apps/data/airports_database.dart';
import '../../../../apps/models/airport_detail_data.dart';
import '../../../apps/providers/simulator/simulator_provider.dart';
import '../../../../apps/services/airport_detail_service.dart';
import '../../../../apps/services/weather_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../apps/providers/airport_info_provider.dart';

import 'airport_detail_view.dart';

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
  final VoidCallback onRefreshMetar; // 新增：手动刷新气象回调

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
    required this.onRefreshMetar,
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

          AirportDetailView(
            airport: widget.airport,
            metar: displayMetar,
            metarError: widget.metarError,
            detail: currentDetail,
            detailError: widget.detailError,
            isLoading: widget.isLoading,
            onRefreshMetar: () async {
              // 检查设定数据失效范围
              final prefs = await SharedPreferences.getInstance();
              final expiry = prefs.getInt('metar_cache_expiry') ?? 60;
              if (displayMetar == null || displayMetar.isExpired(expiry)) {
                widget.onRefreshMetar();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '气象数据尚在 $expiry 分钟有效期内，无需刷新 (剩余约 ${(expiry - DateTime.now().difference(displayMetar.timestamp).inMinutes).clamp(0, expiry)} 分钟)',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),
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
                              : context
                                    .read<AirportInfoProvider>()
                                    .currentDataSource
                                    .shortName),
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
