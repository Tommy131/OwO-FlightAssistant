import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/flight_logs_localization_keys.dart';
import '../../models/flight_log_models.dart';

class FlightLogListItem extends StatelessWidget {
  final FlightLog log;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onExport;

  const FlightLogListItem({
    super.key,
    required this.log,
    this.onTap,
    this.onDelete,
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final borderColor = AppThemeData.getBorderColor(
      theme,
    ).withValues(alpha: isDark ? 0.4 : 0.6);
    final duration = log.duration;
    final durationText = '${duration.inHours}h ${duration.inMinutes % 60}m';
    final routeBackground = theme.colorScheme.surfaceContainerHighest;
    final landingRating = log.landingData?.rating;
    final isCompleted = log.isCompleted;
    final arrivalText = isCompleted
        ? (log.arrivalAirport ??
              FlightLogsLocalizationKeys.listUnknownAirport.tr(context))
        : '----';

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
                    child: Text(
                      log.aircraftTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildSimulatorBadge(context, log.simulatorLabel),
                  const SizedBox(width: 8),
                  if (!isCompleted) _buildIncompleteBadge(context),
                  if (isCompleted)
                    _buildLandingRatingBadge(context, landingRating),
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
                      FlightLogsLocalizationKeys.listDeparture.tr(context),
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
                      FlightLogsLocalizationKeys.listArrival.tr(context),
                      arrivalText,
                      Icons.flight_land,
                      crossAxisAlignment: CrossAxisAlignment.end,
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  _buildStatItem(context, Icons.timer_outlined, durationText),
                  const SizedBox(width: 16),
                  _buildStatItem(
                    context,
                    Icons.speed,
                    '${log.maxGroundSpeed.toStringAsFixed(0)} kts',
                  ),
                  const Spacer(),
                  if (onExport != null || onDelete != null)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'export') onExport?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) => [
                        if (onExport != null)
                          PopupMenuItem(
                            value: 'export',
                            child: Row(
                              children: [
                                const Icon(Icons.share_outlined, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  FlightLogsLocalizationKeys.exportLog.tr(
                                    context,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (onDelete != null)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.redAccent,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  FlightLogsLocalizationKeys.deleteLog.tr(
                                    context,
                                  ),
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
              const SizedBox(height: 6),
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

  Widget _buildLandingRatingBadge(BuildContext context, LandingRating? rating) {
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
        _landingRatingLabel(context, rating),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildIncompleteBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        FlightLogsLocalizationKeys.listIncompleteFlight.tr(context),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSimulatorBadge(BuildContext context, String? simulatorLabel) {
    final theme = Theme.of(context);
    final normalized = (simulatorLabel ?? '').toUpperCase();
    final key = normalized.contains('X-PLANE')
        ? FlightLogsLocalizationKeys.simulatorXplane
        : normalized.contains('MSFS')
        ? FlightLogsLocalizationKeys.simulatorMsfs
        : FlightLogsLocalizationKeys.simulatorUnknown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        key.tr(context),
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _landingRatingLabel(BuildContext context, LandingRating rating) {
    switch (rating) {
      case LandingRating.perfect:
        return FlightLogsLocalizationKeys.ratingPerfect.tr(context);
      case LandingRating.soft:
        return FlightLogsLocalizationKeys.ratingSoft.tr(context);
      case LandingRating.acceptable:
        return FlightLogsLocalizationKeys.ratingAcceptable.tr(context);
      case LandingRating.hard:
        return FlightLogsLocalizationKeys.ratingHard.tr(context);
      case LandingRating.fired:
        return FlightLogsLocalizationKeys.ratingFired.tr(context);
      case LandingRating.rip:
        return FlightLogsLocalizationKeys.ratingRip.tr(context);
    }
  }
}
