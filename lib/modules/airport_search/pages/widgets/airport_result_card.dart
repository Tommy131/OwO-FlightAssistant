import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../common/widgets/wind_direction_indicator.dart';
import '../../localization/airport_search_localization_keys.dart';
import '../../models/airport_search_models.dart';
// 新引入的拆分组件
import 'result_card_common_widgets.dart';
import 'result_card_runway_widgets.dart';
import 'result_card_frequency_widgets.dart';

/// 机场搜索结果详情卡片
/// 展示包含了坐标、METAR 气象、跑道信息、通讯频率等全方位的机场数据
class AirportResultCard extends StatelessWidget {
  /// 查询结果数据对象
  final AirportQueryResult? result;

  /// 是否已被加入收藏
  final bool isFavorite;

  /// 切换收藏状态的回调
  final VoidCallback onToggleFavorite;

  const AirportResultCard({
    super.key,
    required this.result,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    // 1. 无结果状态处理
    final query = result;
    if (query == null) {
      return _buildNoResult(context);
    }

    // 2. 数据与主题变量准备
    final airport = query.airport;
    final metar = query.metar;
    final title = airport.name ?? airport.icao;
    // 合并同类型的频率条目
    final frequencyRows = mergeFrequencyRows(airport.frequencies);
    // 从原始 METAR 文本中提取解析风向数据
    final wind = _extractWind(metar);

    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    // 混合同色调以创建自适应背景
    final cardBackground = Color.alphaBlend(
      accent.withValues(alpha: 0.1),
      theme.colorScheme.surface,
    );
    final panelBackground = Color.alphaBlend(
      accent.withValues(alpha: 0.5),
      theme.colorScheme.surfaceContainerHighest,
    );
    final lineColor = accent.withValues(alpha: 0.35);

    // 构建位置文本与跑道数据对象列表
    final locationText = _buildLocationText(airport);
    final runwayCards = _buildRunwayCardData(airport.runways);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(color: lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部状态栏: ICAO、名称、IATA/来源标签及收藏按钮
          Row(
            children: [
              Text(
                airport.icao,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    if (airport.iata != null && airport.iata!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      ResultCardTagChip(text: airport.iata!),
                    ] else if (airport.source != null &&
                        airport.source!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      ResultCardTagChip(text: airport.source!),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggleFavorite,
                tooltip: isFavorite
                    ? AirportSearchLocalizationKeys.favoriteRemove.tr(context)
                    : AirportSearchLocalizationKeys.favoriteAdd.tr(context),
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_outline,
                  size: 20,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: lineColor),
          const SizedBox(height: 8),

          // 根据宽度响应式动态布局 (风向指示器 + 右侧详情面板)
          LayoutBuilder(
            builder: (context, constraints) {
              final rightPanel = _buildRightDetailPanel(
                context,
                airport,
                metar,
                locationText,
                runwayCards,
                panelBackground,
              );
              // 如果宽度不足 (移动端或侧边栏模式)，切换为垂直布局
              if (constraints.maxWidth < 860) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWindIndicatorPanel(context, wind),
                    const SizedBox(height: 8),
                    rightPanel,
                  ],
                );
              }
              // 桌面端水平布局
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 155,
                    child: _buildWindIndicatorPanel(context, wind),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: rightPanel),
                ],
              );
            },
          ),

          const SizedBox(height: 8),
          Divider(color: lineColor),
          const SizedBox(height: 8),

          // 通讯频率部分
          Row(
            children: [
              Icon(Icons.settings_input_antenna, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                AirportSearchLocalizationKeys.frequenciesTitle.tr(context),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingSmall),
          if (frequencyRows.isEmpty)
            Text(
              AirportSearchLocalizationKeys.frequenciesEmpty.tr(context),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            )
          else
            ResultFrequencyTable(rows: frequencyRows),
        ],
      ),
    );
  }

  /// 构建空结果展示样式
  Widget _buildNoResult(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(
          color: AppThemeData.getBorderColor(
            Theme.of(context),
          ).withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        AirportSearchLocalizationKeys.noResultHint.tr(context),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  /// 构建右侧核心详情面板: 位置坐标、气象详情、跑道列表
  Widget _buildRightDetailPanel(
    BuildContext context,
    AirportDetailData airport,
    MetarData metar,
    String locationText,
    List<RunwayCardData> runwayCards,
    Color panelBackground,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 位置信息
        ResultCardSectionHeader(
          icon: Icons.place_outlined,
          title: AirportSearchLocalizationKeys.positionSectionTitle.tr(context),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: panelBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            locationText,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 2. 气象相关信息 (METAR 与数据徽章)
        ResultCardSectionHeader(
          icon: Icons.cloud_outlined,
          title: AirportSearchLocalizationKeys.weatherSectionTitle.tr(context),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: panelBackground,
            borderRadius: BorderRadius.circular(AppThemeData.borderRadiusSmall),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SelectableText(
            (metar.raw ?? '').trim().isEmpty
                ? AirportSearchLocalizationKeys.metarEmpty.tr(context)
                : metar.raw!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ResultCardMetaBadge(
              label: AirportSearchLocalizationKeys.metarWind.tr(context),
              value: metar.wind ?? '-',
            ),
            ResultCardMetaBadge(
              label: AirportSearchLocalizationKeys.metarVisibility.tr(context),
              value: metar.visibility ?? '-',
            ),
            ResultCardMetaBadge(
              label: AirportSearchLocalizationKeys.metarTemperature.tr(context),
              value: metar.temperature ?? '-',
            ),
            ResultCardMetaBadge(
              label: AirportSearchLocalizationKeys.metarAltimeter.tr(context),
              value: metar.altimeter ?? '-',
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 3. 跑道列表
        ResultCardSectionHeader(
          icon: Icons.flight_land_outlined,
          title: AirportSearchLocalizationKeys.runwaySectionTitle.tr(context),
        ),
        const SizedBox(height: 4),
        if (runwayCards.isEmpty)
          Text(
            AirportSearchLocalizationKeys.runwaysEmpty.tr(context),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: runwayCards
                .map((item) => ResultRunwayCard(data: item))
                .toList(),
          ),
      ],
    );
  }

  /// 构建风向指示器组件块
  Widget _buildWindIndicatorPanel(BuildContext context, _WindSnapshot wind) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WindDirectionIndicator(
            windDirection: wind.direction,
            windSpeed: wind.speedKt,
            size: 120,
          ),
        ],
      ),
    );
  }

  /// 生成位置描述文本 (经度、纬度、海拔)
  String _buildLocationText(AirportDetailData airport) {
    final lat = airport.latitude?.toStringAsFixed(5) ?? '-';
    final lon = airport.longitude?.toStringAsFixed(5) ?? '-';
    final elev = airport.elevationFt == null
        ? '-'
        : '${airport.elevationFt} ft';
    return 'LAT: $lat   LON: $lon   ELEV: $elev';
  }

  /// 转换跑道模型列表为展示用数据
  List<RunwayCardData> _buildRunwayCardData(List<AirportRunwayData> runways) {
    return runways
        .map(
          (runway) => RunwayCardData(
            ident: runway.ident,
            length: runway.lengthM == null
                ? '-'
                : '${runway.lengthM!.toStringAsFixed(0)} m',
            surface: runway.surface ?? '-',
          ),
        )
        .toList();
  }

  /// 风向提取助手: 从原始文本或 API 提取风向度数和风速
  _WindSnapshot _extractWind(MetarData metar) {
    final raw = metar.raw ?? '';
    // 使用正则从标准 METAR 字符串中匹配 (3位方向 + 2-3位风速 + 选配阵风G)
    final rawMatch = RegExp(
      r'\b(?:(\d{3})|VRB)(\d{2,3})(?:G\d{2,3})?KT\b',
      caseSensitive: false,
    ).firstMatch(raw);

    if (rawMatch != null) {
      return _WindSnapshot(
        direction: double.tryParse(rawMatch.group(1) ?? ''),
        speedKt: double.tryParse(rawMatch.group(2) ?? ''),
        rawText: metar.wind,
      );
    }

    // 逻辑备选: 从已翻译/解码的文本中提取 (中文/英文描述)
    final windText = metar.wind ?? metar.decoded ?? '';
    final directionMatch = RegExp(r'(\d{1,3})\s*[°度]').firstMatch(windText);
    final speedMatch = RegExp(
      r'(?:/|\s)(\d{1,3})(?:\s*(?:kt|kts|m/s|米/秒))?',
      caseSensitive: false,
    ).firstMatch(windText);

    return _WindSnapshot(
      direction: double.tryParse(directionMatch?.group(1) ?? ''),
      speedKt: double.tryParse(speedMatch?.group(1) ?? ''),
      rawText: metar.wind,
    );
  }
}

/// 内部风向状态快照
class _WindSnapshot {
  final double? direction;
  final double? speedKt;
  final String? rawText;

  const _WindSnapshot({this.direction, this.speedKt, this.rawText});
}
