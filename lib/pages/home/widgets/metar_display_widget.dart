import 'package:flutter/material.dart';
import '../../../apps/services/weather_service.dart';
import '../../../core/theme/app_theme_data.dart';

/// 可复用的 METAR 气象报文显示组件
class MetarDisplayWidget extends StatelessWidget {
  final String airportLabel;
  final MetarData metarData;
  final bool showUpdateTime;
  final bool compact;

  const MetarDisplayWidget({
    super.key,
    required this.airportLabel,
    required this.metarData,
    this.showUpdateTime = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with airport label and update time
          Row(
            children: [
              Text(
                airportLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (showUpdateTime) ...[
                const Spacer(),
                Text(
                  '更新于: ${metarData.timestamp.hour.toString().padLeft(2, "0")}:${metarData.timestamp.minute.toString().padLeft(2, "0")}:${metarData.timestamp.second.toString().padLeft(2, "0")}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),

          // Raw METAR
          if (!compact)
            Container(
              padding: const EdgeInsets.all(8),
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
                  fontSize: 11,
                ),
              ),
            ),
          if (!compact) const SizedBox(height: 4),

          // Parsed data tags
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildMetarTag(theme, '风: ${metarData.displayWind}'),
              _buildMetarTag(theme, '能见度: ${metarData.displayVisibility}'),
              _buildMetarTag(theme, '温/露: ${metarData.displayTemperature}'),
              _buildMetarTag(theme, '修正海压: ${metarData.displayAltimeter}'),
            ],
          ),
        ],
      ),
    );
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

/// METAR 区域容器组件
class MetarSectionWidget extends StatelessWidget {
  final Map<String, MetarData> metars;
  final Map<String, String> errors;
  final bool compact;

  const MetarSectionWidget({
    super.key,
    required this.metars,
    this.errors = const {},
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Don't show the section if there are no metars AND no errors
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
                '气象报文 (METAR)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : AppThemeData.spacingMedium),

          // Display successful METARs
          ...metars.entries.map(
            (e) => MetarDisplayWidget(
              airportLabel: e.key,
              metarData: e.value,
              compact: compact,
            ),
          ),

          // Display METAR errors
          ...errors.entries.map((e) => _buildMetarError(theme, e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildMetarError(ThemeData theme, String label, String errorMessage) {
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
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '气象报文获取失败',
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
              errorMessage,
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
