import 'package:flutter/material.dart';
import '../../../apps/models/flight_log.dart';
import '../../../core/theme/app_theme_data.dart';

class AnalysisSummaryCard extends StatelessWidget {
  final FlightLog log;

  const AnalysisSummaryCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final duration = log.duration;
    final hrs = duration.inHours;
    final mins = duration.inMinutes % 60;
    final secs = duration.inSeconds % 60;

    return Column(
      children: [
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
              '总飞行时间',
              '${hrs}h ${mins}m ${secs}s',
              Icons.timer_outlined,
              Colors.blue,
            ),
            _buildSummaryItem(
              context,
              '最大高度',
              '${log.maxAltitude.toStringAsFixed(0)} ft',
              Icons.landscape,
              Colors.orange,
            ),
            _buildSummaryItem(
              context,
              '最高地速',
              '${log.maxGroundSpeed.toStringAsFixed(0)} kts',
              Icons.speed,
              Colors.redAccent,
            ),
            _buildSummaryItem(
              context,
              '燃油消耗',
              '${log.totalFuelUsed?.toStringAsFixed(1) ?? "N/A"} kg',
              Icons.local_gas_station,
              Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 12),
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
              '起飞机场',
              log.departureAirport,
              Icons.flight_takeoff,
              Colors.indigo,
            ),
            _buildSummaryItem(
              context,
              '降落机场',
              log.arrivalAirport ?? '未知',
              Icons.flight_land,
              Colors.deepPurple,
            ),
            _buildSummaryItem(
              context,
              '最大重力',
              '${log.maxG.toStringAsFixed(2)} G',
              Icons.vibration,
              Colors.amber,
            ),
            _buildSummaryItem(
              context,
              '最小重力',
              '${log.minG.toStringAsFixed(2)} G',
              Icons.vertical_align_bottom,
              Colors.teal,
            ),
          ],
        ),
      ],
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
