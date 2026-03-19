import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/localization_service.dart';
import '../../localization/flight_logs_localization_keys.dart';
import '../../models/flight_log_models.dart';

class AnalysisBlackBox extends StatefulWidget {
  final FlightLog log;

  const AnalysisBlackBox({super.key, required this.log});

  @override
  State<AnalysisBlackBox> createState() => _AnalysisBlackBoxState();
}

class _AnalysisBlackBoxState extends State<AnalysisBlackBox> {
  static const List<int> _pageSizes = [20, 50, 100];
  int _rowsPerPage = _pageSizes.first;
  int _currentPage = 0;
  late final ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController(keepScrollOffset: false);
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.log.points.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeFormat = DateFormat('HH:mm:ss');
    final availablePageSizes = _pageSizes
        .where((size) => size <= widget.log.points.length)
        .toList();
    if (availablePageSizes.isEmpty) {
      availablePageSizes.add(widget.log.points.length);
    }
    final rowsPerPage = availablePageSizes.contains(_rowsPerPage)
        ? _rowsPerPage
        : availablePageSizes.first;
    final totalPages = (widget.log.points.length / rowsPerPage).ceil();
    final currentPage = _currentPage >= totalPages
        ? totalPages - 1
        : _currentPage;
    final start = currentPage * rowsPerPage;
    final end = (start + rowsPerPage)
        .clamp(0, widget.log.points.length)
        .toInt();
    final pagePoints = widget.log.points.sublist(start, end);

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
                  FlightLogsLocalizationKeys.blackBoxTitle.tr(context),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.log.points.length} ${FlightLogsLocalizationKeys.blackBoxRows.tr(context)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            key: const ValueKey<String>('black_box_table_horizontal_scroll'),
            scrollDirection: Axis.horizontal,
            controller: _horizontalController,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1500),
              child: DataTable(
                columnSpacing: 24,
                horizontalMargin: 16,
                headingRowHeight: 40,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 32,
                columns: [
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxTime.tr(context),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxAltitude.tr(context),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxGroundSpeed.tr(
                        context,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxHeading.tr(context),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxPosition.tr(context),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxVerticalSpeed.tr(
                        context,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxGForce.tr(context),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxAoa.tr(context),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxApAt.tr(context),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxFlapsGear.tr(context),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxWind.tr(context),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxSystem.tr(context),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxBaro.tr(context),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxAlert.tr(context),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxAnomalyAlert.tr(
                        context,
                      ),
                    ),
                  ),
                ],
                rows: pagePoints.map((p) {
                  final anomalyText = p.anomalyAlerts.isEmpty
                      ? '-'
                      : p.anomalyAlerts
                            .map((alert) => alert.message.tr(context))
                            .join(' | ');
                  final highestLevel = p.anomalyAlerts
                      .fold<FlightLogAlertLevel>(FlightLogAlertLevel.caution, (
                        current,
                        alert,
                      ) {
                        if (alert.level == FlightLogAlertLevel.danger) {
                          return FlightLogAlertLevel.danger;
                        }
                        if (alert.level == FlightLogAlertLevel.warning &&
                            current == FlightLogAlertLevel.caution) {
                          return FlightLogAlertLevel.warning;
                        }
                        return current;
                      });
                  return DataRow(
                    cells: [
                      DataCell(Text(timeFormat.format(p.timestamp.toUtc()))),
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
                          p.angleOfAttack != null
                              ? p.angleOfAttack!.toStringAsFixed(1)
                              : '-',
                        ),
                      ),
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
                      DataCell(Text(p.baroPressure?.toStringAsFixed(2) ?? "-")),
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
                      DataCell(
                        Text(
                          anomalyText,
                          style: TextStyle(
                            color: p.anomalyAlerts.isEmpty
                                ? null
                                : highestLevel == FlightLogAlertLevel.danger
                                ? Colors.red
                                : highestLevel == FlightLogAlertLevel.warning
                                ? Colors.orange
                                : theme.colorScheme.primary,
                            fontWeight: p.anomalyAlerts.isEmpty
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  '${currentPage + 1}/$totalPages',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: currentPage > 0
                      ? () {
                          setState(() {
                            _currentPage = currentPage - 1;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  onPressed: currentPage < totalPages - 1
                      ? () {
                          setState(() {
                            _currentPage = currentPage + 1;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                const Spacer(),
                DropdownButton<int>(
                  value: rowsPerPage,
                  items: availablePageSizes
                      .map(
                        (size) => DropdownMenuItem<int>(
                          value: size,
                          child: Text('$size / 页'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _rowsPerPage = value;
                      _currentPage = 0;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
