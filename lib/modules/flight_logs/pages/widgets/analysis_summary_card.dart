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
    final totalRecordedDuration = log.totalRecordedDuration;
    final airborneDuration = log.airborneDuration;
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
    final summaryItems = <_SummaryItemData>[
      _SummaryItemData(
        label: FlightLogsLocalizationKeys.summaryDuration.tr(context),
        value: _formatDuration(totalRecordedDuration),
        icon: Icons.timer_outlined,
        color: Colors.blue,
      ),
      _SummaryItemData(
        label: FlightLogsLocalizationKeys.summaryAirborneDuration.tr(context),
        value: _formatDuration(airborneDuration),
        icon: Icons.timer_outlined,
        color: Colors.cyan,
      ),
      _SummaryItemData(
        label: FlightLogsLocalizationKeys.summaryMaxAlt.tr(context),
        value: '${log.maxAltitude.toStringAsFixed(0)} ft',
        icon: Icons.height,
        color: Colors.purple,
      ),
      _SummaryItemData(
        label: FlightLogsLocalizationKeys.summaryMaxGs.tr(context),
        value: '${log.maxGroundSpeed.toStringAsFixed(0)} kts',
        icon: Icons.speed,
        color: Colors.orange,
      ),
      _SummaryItemData(
        label: FlightLogsLocalizationKeys.summaryFuel.tr(context),
        value: log.totalFuelUsed != null
            ? '${log.totalFuelUsed!.toStringAsFixed(1)} kg'
            : '--',
        icon: Icons.local_gas_station_outlined,
        color: Colors.green,
      ),
      _SummaryItemData(
        label: FlightLogsLocalizationKeys.listDeparture.tr(context),
        value: departureAirport,
        icon: Icons.flight_takeoff,
        color: Colors.teal,
      ),
      _SummaryItemData(
        label: FlightLogsLocalizationKeys.listArrival.tr(context),
        value: arrivalAirport,
        icon: Icons.flight_land,
        color: Colors.deepOrange,
      ),
      _SummaryItemData(
        label: FlightLogsLocalizationKeys.summaryMaxG.tr(context),
        value: '${log.maxG.toStringAsFixed(2)} G',
        icon: Icons.trending_up,
        color: Colors.redAccent,
      ),
      _SummaryItemData(
        label: FlightLogsLocalizationKeys.summaryMinG.tr(context),
        value: '${log.minG.toStringAsFixed(2)} G',
        icon: Icons.trending_down,
        color: Colors.indigo,
      ),
      _SummaryItemData(
        label: FlightLogsLocalizationKeys.summaryTouchdownG.tr(context),
        value: log.landingData != null
            ? '${log.landingData!.gForce.toStringAsFixed(2)} G'
            : '--',
        icon: Icons.flight_land,
        color: Colors.green,
      ),
    ];

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
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              if (width < 760) {
                return Column(
                  children: summaryItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == summaryItems.length - 1 ? 0 : 10,
                      ),
                      child: _buildCompactSummaryItem(
                        context,
                        item.label,
                        item.value,
                        item.icon,
                        item.color,
                      ),
                    );
                  }).toList(),
                );
              }
              final preferredTileWidth = width >= 1800
                  ? 250.0
                  : width >= 1400
                  ? 270.0
                  : width >= 1000
                  ? 300.0
                  : 220.0;
              final crossAxisCount = (width / preferredTileWidth)
                  .floor()
                  .clamp(2, 6)
                  .toInt();
              final childAspectRatio = width >= 1800
                  ? 4.0
                  : width >= 1400
                  ? 3.5
                  : width >= 1000
                  ? 3.0
                  : 2.2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: summaryItems.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final item = summaryItems[index];
                  return _buildSummaryItem(
                    context,
                    item.label,
                    item.value,
                    item.icon,
                    item.color,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSummaryItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppThemeData.spacingMedium,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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

  String _formatDuration(Duration duration) {
    final hrs = duration.inHours;
    final mins = duration.inMinutes % 60;
    final secs = duration.inSeconds % 60;
    return '${hrs}h ${mins}m ${secs}s';
  }
}

class _SummaryItemData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryItemData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
