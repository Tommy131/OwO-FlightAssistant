import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../apps/models/flight_log.dart';

class AnalysisBlackBox extends StatelessWidget {
  final FlightLog log;

  const AnalysisBlackBox({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    if (log.points.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeFormat = DateFormat('HH:mm:ss');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.settings_input_component, size: 20),
                const SizedBox(width: 12),
                Text(
                  '黑匣子数据明细 (每2秒采样)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '共 ${log.points.length} 条记录',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              horizontalMargin: 16,
              headingRowHeight: 40,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 32,
              headingTextStyle: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              columns: const [
                DataColumn(label: Text('时间')),
                DataColumn(label: Text('高度(ft)')),
                DataColumn(label: Text('地速(kts)')),
                DataColumn(label: Text('航向(°)')),
                DataColumn(label: Text('经纬度')),
                DataColumn(label: Text('VS(fpm)')),
                DataColumn(label: Text('G值')),
                DataColumn(label: Text('AP/AT')),
                DataColumn(label: Text('襟翼/起落架')),
                DataColumn(label: Text('风速/风向')),
                DataColumn(label: Text('系统状态'), tooltip: '地面状态/自动刹车/减速板'),
                DataColumn(label: Text('修正海压')),
                DataColumn(label: Text('警告/告警')),
              ],
              rows: log.points
                  .map(
                    (p) => DataRow(
                      cells: [
                        DataCell(
                          Text(timeFormat.format(p.timestamp.toLocal())),
                        ),
                        DataCell(Text(p.altitude.toStringAsFixed(0))),
                        DataCell(Text(p.groundSpeed.toStringAsFixed(0))),
                        DataCell(Text(p.heading.toStringAsFixed(0))),
                        DataCell(
                          Text(
                            '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        DataCell(Text(p.verticalSpeed.toStringAsFixed(0))),
                        DataCell(Text(p.gForce.toStringAsFixed(2))),
                        DataCell(
                          Text(
                            '${p.autopilotEngaged == true ? "ON" : "OFF"}/${p.autothrottleEngaged == true ? "ON" : "OFF"}',
                          ),
                        ),
                        DataCell(
                          Text(
                            '${p.flapsLabel ?? p.flapsPosition?.toString() ?? "-"}/${p.gearDown == true ? "DN" : "UP"}',
                          ),
                        ),
                        DataCell(
                          Text(
                            '${p.windSpeed?.toStringAsFixed(0) ?? "-"}/${p.windDirection?.toStringAsFixed(0) ?? "-"}',
                          ),
                        ),
                        DataCell(
                          Text(
                            '${p.onGround == true ? "GND" : "AIR"} / AB:${p.autoBrakeLevel ?? 0} / SB:${((p.speedBrakePosition ?? 0) * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        DataCell(
                          Text(p.baroPressure?.toStringAsFixed(2) ?? "-"),
                        ),
                        DataCell(
                          Text(
                            '${p.masterWarning == true ? "⚠" : "-"}/${p.masterCaution == true ? "!" : "-"}',
                            style: TextStyle(
                              color: p.masterWarning == true
                                  ? Colors.red
                                  : p.masterCaution == true
                                  ? Colors.orange
                                  : null,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
