import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/common_localization_keys.dart';
import '../../models/home_models.dart';

class MetarDisplayWidget extends StatelessWidget {
  final String airportLabel;
  final HomeMetarData metarData;
  final bool showUpdateTime;
  final bool compact;
  final IconData? icon;
  final VoidCallback? onRefresh;
  final bool? isRefreshing;

  const MetarDisplayWidget({
    super.key,
    required this.airportLabel,
    required this.metarData,
    this.showUpdateTime = true,
    this.compact = false,
    this.icon,
    this.onRefresh,
    this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabel = _buildTimeLabel(context, metarData.timestamp);

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: theme.colorScheme.primary, size: 14),
                const SizedBox(width: 6),
              ],
              Text(
                airportLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              if (showUpdateTime) ...[
                const Spacer(),
                if (onRefresh != null) ...[
                  if (isRefreshing == true)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  else
                    InkWell(
                      onTap: onRefresh,
                      borderRadius: BorderRadius.circular(12),
                      child: Icon(
                        Icons.refresh,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
                Text(
                  timeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: EdgeInsets.all(compact ? 4 : 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              metarData.raw,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'Monospace',
                fontSize: compact ? 9 : 11,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildMetarTag(
                theme,
                '${CommonLocalizationKeys.metarWind.tr(context)}: ${metarData.displayWind}',
              ),
              _buildMetarTag(
                theme,
                '${CommonLocalizationKeys.metarVisibility.tr(context)}: ${metarData.displayVisibility}',
              ),
              _buildMetarTag(
                theme,
                '${CommonLocalizationKeys.metarTemperature.tr(context)}: ${metarData.displayTemperature}',
              ),
              _buildMetarTag(
                theme,
                '${CommonLocalizationKeys.metarAltimeter.tr(context)}: ${metarData.displayAltimeter}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildTimeLabel(BuildContext context, DateTime time) {
    final formatted =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
    return CommonLocalizationKeys.metarUpdatedAt
        .tr(context)
        .replaceAll('{time}', formatted);
  }

  Widget _buildMetarTag(ThemeData theme, String text) {
    return Container(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(fontSize: compact ? 9 : 10),
      ),
    );
  }
}

class MetarSectionWidget extends StatelessWidget {
  final Map<String, HomeMetarData> metars;
  final Map<String, String> errors;
  final Map<String, VoidCallback> refreshCallbacks;
  final bool compact;

  const MetarSectionWidget({
    super.key,
    required this.metars,
    this.errors = const {},
    this.refreshCallbacks = const {},
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (metars.isEmpty && errors.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(
        compact ? AppThemeData.spacingMedium : AppThemeData.spacingLarge,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(color: AppThemeData.getBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                CommonLocalizationKeys.metarTitle.tr(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : AppThemeData.spacingMedium),
          ...metars.entries.map(
            (e) => MetarDisplayWidget(
              airportLabel: e.key,
              metarData: e.value,
              compact: compact,
              onRefresh: refreshCallbacks[e.key],
            ),
          ),
          ...errors.entries.map((e) => _buildMetarError(context, theme, e)),
        ],
      ),
    );
  }

  Widget _buildMetarError(
    BuildContext context,
    ThemeData theme,
    MapEntry<String, String> entry,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CommonLocalizationKeys.metarErrorTitle.tr(context),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.value.isNotEmpty
                  ? entry.value
                  : CommonLocalizationKeys.metarErrorDefault.tr(context),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
