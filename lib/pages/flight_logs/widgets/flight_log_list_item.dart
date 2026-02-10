import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../apps/models/flight_log.dart';
import '../../../core/theme/app_theme_data.dart';

class FlightLogListItem extends StatelessWidget {
  final FlightLog log;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const FlightLogListItem({
    super.key,
    required this.log,
    required this.onTap,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final duration = log.duration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    final borderColor = AppThemeData.getBorderColor(
      theme,
    ).withValues(alpha: isDark ? 0.4 : 0.6);
    final routeBackground = theme.colorScheme.surfaceContainerHighest;

    return Card(
      margin: const EdgeInsets.only(bottom: AppThemeData.spacingMedium),
      elevation: 1.2,
      shadowColor: theme.shadowColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        side: BorderSide(color: borderColor),
      ),
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppThemeData.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.flight_outlined,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.aircraftTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          dateFormat.format(log.startTime),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildLandingRatingBadge(log.landingData?.rating),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: routeBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    _buildInfoColumn(
                      context,
                      '起飞',
                      log.departureAirport,
                      Icons.flight_takeoff,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildInfoColumn(
                      context,
                      '到达',
                      log.arrivalAirport ?? '未知',
                      Icons.flight_land,
                      crossAxisAlignment: CrossAxisAlignment.end,
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  _buildStatItem(
                    context,
                    Icons.timer_outlined,
                    '${hours}h ${minutes}m',
                  ),
                  const SizedBox(width: 16),
                  _buildStatItem(
                    context,
                    Icons.speed,
                    '${log.maxGroundSpeed.toStringAsFixed(0)} kts',
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'export') onExport();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.share_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('导出'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '删除',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: const Icon(Icons.more_vert, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.hintColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildLandingRatingBadge(LandingRating? rating) {
    if (rating == null) return const SizedBox.shrink();

    Color color;
    switch (rating) {
      case LandingRating.perfect:
        color = Colors.green;
        break;
      case LandingRating.soft:
        color = Colors.blue;
        break;
      case LandingRating.acceptable:
        color = Colors.orange;
        break;
      case LandingRating.hard:
      case LandingRating.fired:
      case LandingRating.rip:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        rating.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
