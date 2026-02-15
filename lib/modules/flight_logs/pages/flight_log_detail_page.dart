import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/dialog.dart';
import '../localization/flight_logs_localization_keys.dart';
import '../models/flight_log_models.dart';
import '../providers/flight_logs_provider.dart';
import 'widgets/analysis_black_box.dart';
import 'widgets/analysis_chart.dart';
import 'widgets/analysis_summary_card.dart';
import 'widgets/analysis_track_map.dart';

class FlightLogDetailPage extends StatelessWidget {
  final FlightLog log;
  final VoidCallback? onBack;

  const FlightLogDetailPage({super.key, required this.log, this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack,
              )
            : null,
        title: Text(
          '${log.aircraftTitle} - ${FlightLogsLocalizationKeys.detailTitle.tr(context)}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              showLoadingDialog(
                context: context,
                title: FlightLogsLocalizationKeys.exportLog.tr(context),
              );
              try {
                final provider = context.read<FlightLogsProvider>();
                await provider.exportLog(log);
                if (context.mounted) {
                  _closeDialog(context);
                }
              } catch (e) {
                if (context.mounted) {
                  _closeDialog(context);
                  showAdvancedConfirmDialog(
                    context: context,
                    title: FlightLogsLocalizationKeys.exportLog.tr(context),
                    content: e.toString(),
                    icon: Icons.error_outline_rounded,
                    confirmColor: Colors.redAccent,
                    confirmText: FlightLogsLocalizationKeys.cancel.tr(context),
                    cancelText: '',
                  );
                }
              }
            },
          ),
          const SizedBox(width: AppThemeData.spacingSmall),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnalysisSummaryCard(log: log),
            const SizedBox(height: 24),
            _buildEventSection(context),
            const SizedBox(height: 24),
            Text(
              FlightLogsLocalizationKeys.detailTrack.tr(context),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            AnalysisTrackMap(log: log),
            const SizedBox(height: 24),
            Text(
              FlightLogsLocalizationKeys.detailProfile.tr(context),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            AnalysisChart(log: log),
            const SizedBox(height: 24),
            AnalysisBlackBox(log: log),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _closeDialog(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Widget _buildEventSection(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (log.takeoffData != null)
          Expanded(
            child: _buildEventCard(
              context,
              FlightLogsLocalizationKeys.eventTakeoff.tr(context),
              log.takeoffData!,
              true,
            ),
          ),
        if (log.takeoffData != null && log.landingData != null)
          const SizedBox(width: 16),
        if (log.landingData != null)
          Expanded(
            child: _buildEventCard(
              context,
              FlightLogsLocalizationKeys.eventLanding.tr(context),
              log.landingData!,
              false,
            ),
          ),
      ],
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    String title,
    dynamic data,
    bool isTakeoff,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isTakeoff ? Icons.flight_takeoff : Icons.flight_land,
                color: isTakeoff ? Colors.blue : Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isTakeoff && data is LandingData) ...[
                const Spacer(),
                _buildRatingBadge(context, data.rating),
              ],
            ],
          ),
          const Divider(height: 24),
          _buildDetailRow(
            FlightLogsLocalizationKeys.runway.tr(context),
            data.runway ?? '--',
          ),
          _buildDetailRow(
            FlightLogsLocalizationKeys.airspeed.tr(context),
            '${data.airspeed.toStringAsFixed(1)} kts',
          ),
          if (data is LandingData) ...[
            _buildDetailRow(
              FlightLogsLocalizationKeys.verticalSpeed.tr(context),
              '${data.verticalSpeed.toStringAsFixed(0)} fpm',
            ),
            _buildDetailRow(
              FlightLogsLocalizationKeys.gForce.tr(context),
              '${data.gForce.toStringAsFixed(2)} G',
            ),
          ],
          if (data is TakeoffData) ...[
            _buildDetailRow(
              FlightLogsLocalizationKeys.pitch.tr(context),
              '${data.pitch.toStringAsFixed(1)}°',
            ),
            _buildDetailRow(
              FlightLogsLocalizationKeys.heading.tr(context),
              '${data.heading.toStringAsFixed(0)}°',
            ),
          ],
          _buildDetailRow(
            FlightLogsLocalizationKeys.remainingRunway.tr(context),
            '${data.remainingRunwayFt?.toStringAsFixed(0) ?? "--"} ft',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge(BuildContext context, LandingRating rating) {
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
      default:
        color = Colors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _landingRatingLabel(context, rating),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
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
