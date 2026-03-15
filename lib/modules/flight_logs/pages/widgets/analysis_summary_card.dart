import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/flight_logs_localization_keys.dart';
import '../../models/flight_log_models.dart';

class AnalysisSummaryCard extends StatelessWidget {
  final FlightLog log;

  const AnalysisSummaryCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final duration = log.duration;
    final hrs = duration.inHours;
    final mins = duration.inMinutes % 60;
    final secs = duration.inSeconds % 60;
    final unknownAirport = FlightLogsLocalizationKeys.listUnknownAirport.tr(
      context,
    );
    final departureAirport = log.departureAirport.isNotEmpty
        ? log.departureAirport
        : unknownAirport;
    final arrivalAirport = log.isCompleted
        ? ((log.arrivalAirport != null && log.arrivalAirport!.isNotEmpty)
              ? log.arrivalAirport!
              : unknownAirport)
        : '----';

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FlightLogsLocalizationKeys.summaryTitle.tr(context),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildSummaryItem(
                context,
                FlightLogsLocalizationKeys.summaryDuration.tr(context),
                '${hrs}h ${mins}m ${secs}s',
                Icons.timer_outlined,
                Colors.blue,
              ),
              _buildSummaryItem(
                context,
                FlightLogsLocalizationKeys.summaryMaxAlt.tr(context),
                '${log.maxAltitude.toStringAsFixed(0)} ft',
                Icons.height,
                Colors.purple,
              ),
              _buildSummaryItem(
                context,
                FlightLogsLocalizationKeys.summaryMaxGs.tr(context),
                '${log.maxGroundSpeed.toStringAsFixed(0)} kts',
                Icons.speed,
                Colors.orange,
              ),
              _buildSummaryItem(
                context,
                FlightLogsLocalizationKeys.summaryFuel.tr(context),
                log.totalFuelUsed != null
                    ? '${log.totalFuelUsed!.toStringAsFixed(1)} kg'
                    : '--',
                Icons.local_gas_station_outlined,
                Colors.green,
              ),
              _buildSummaryItem(
                context,
                FlightLogsLocalizationKeys.listDeparture.tr(context),
                departureAirport,
                Icons.flight_takeoff,
                Colors.teal,
              ),
              _buildSummaryItem(
                context,
                FlightLogsLocalizationKeys.listArrival.tr(context),
                arrivalAirport,
                Icons.flight_land,
                Colors.deepOrange,
              ),
              _buildSummaryItem(
                context,
                FlightLogsLocalizationKeys.summaryMaxG.tr(context),
                '${log.maxG.toStringAsFixed(2)} G',
                Icons.trending_up,
                Colors.redAccent,
              ),
              _buildSummaryItem(
                context,
                FlightLogsLocalizationKeys.summaryMinG.tr(context),
                '${log.minG.toStringAsFixed(2)} G',
                Icons.trending_down,
                Colors.indigo,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingMedium),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
