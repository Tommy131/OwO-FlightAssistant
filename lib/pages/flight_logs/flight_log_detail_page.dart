import 'package:flutter/material.dart';
import '../../../apps/models/flight_log/flight_log.dart';
import '../../../apps/services/flight_log_service.dart';
import '../../../core/theme/app_theme_data.dart';
import 'widgets/analysis_summary_card.dart';
import 'widgets/analysis_track_map.dart';
import 'widgets/analysis_chart.dart';
import 'widgets/analysis_black_box.dart';
import '../../../core/widgets/common/dialog.dart';

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
        title: Text('${log.aircraftTitle} - 飞行分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              showLoadingDialog(context: context, message: '正在准备导出...');
              try {
                await FlightLogService().exportLog(log);
                if (context.mounted) hideLoadingDialog(context);
              } catch (e) {
                if (context.mounted) {
                  hideLoadingDialog(context);
                  showAdvancedConfirmDialog(
                    context: context,
                    title: '导出失败',
                    content: '导出飞行日志时发生错误：$e',
                    icon: Icons.error_outline_rounded,
                    confirmColor: Colors.redAccent,
                    confirmText: '确定',
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
            // 第一部分：摘要
            AnalysisSummaryCard(log: log),
            const SizedBox(height: 24),

            // 第二部分：关键事件 (起飞与降落)
            _buildEventSection(context),
            const SizedBox(height: 24),

            // 第三部分：地图轨迹
            Text(
              '飞行轨迹',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            AnalysisTrackMap(log: log),
            const SizedBox(height: 24),

            // 第四部分：高度与速度曲线
            Text(
              '飞行剖面',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            AnalysisChart(log: log),
            const SizedBox(height: 24),

            // 第五部分：原始数据表格
            AnalysisBlackBox(log: log),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildEventSection(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (log.takeoffData != null)
          Expanded(
            child: _buildEventCard(context, '起飞数据', log.takeoffData!, true),
          ),
        if (log.takeoffData != null && log.landingData != null)
          const SizedBox(width: 16),
        if (log.landingData != null)
          Expanded(
            child: _buildEventCard(context, '降落数据', log.landingData!, false),
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
                _buildRatingBadge(data.rating),
              ],
            ],
          ),
          const Divider(height: 24),
          _buildDetailRow('跑道', data.runway ?? '未知'),
          _buildDetailRow('空速', '${data.airspeed.toStringAsFixed(1)} kts'),
          if (data is LandingData) ...[
            _buildDetailRow(
              '垂直速度',
              '${data.verticalSpeed.toStringAsFixed(0)} fpm',
            ),
            _buildDetailRow('着陆G值', '${data.gForce.toStringAsFixed(2)} G'),
          ],
          if (data is TakeoffData) ...[
            _buildDetailRow('俯仰角', '${data.pitch.toStringAsFixed(1)}°'),
            _buildDetailRow('航向', '${data.heading.toStringAsFixed(0)}°'),
          ],
          _buildDetailRow(
            '剩余跑道',
            '${data.remainingRunwayFt?.toStringAsFixed(0) ?? "N/A"} ft',
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

  Widget _buildRatingBadge(LandingRating rating) {
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
        rating.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
