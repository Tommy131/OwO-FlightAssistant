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
  late final TextEditingController _pageJumpController;
  late final FocusNode _pageJumpFocusNode;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController(keepScrollOffset: false);
    _pageJumpController = TextEditingController(text: '1');
    _pageJumpFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _pageJumpController.dispose();
    _pageJumpFocusNode.dispose();
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
    final pointEvents = _buildPointEvents(context, widget.log);
    final displayedPageText = '${currentPage + 1}';
    if (!_pageJumpFocusNode.hasFocus &&
        _pageJumpController.text != displayedPageText) {
      _pageJumpController.value = TextEditingValue(
        text: displayedPageText,
        selection: TextSelection.collapsed(offset: displayedPageText.length),
      );
    }

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
              constraints: const BoxConstraints(minWidth: 2200),
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
                      FlightLogsLocalizationKeys.blackBoxGSource.tr(context),
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
                      FlightLogsLocalizationKeys.blackBoxFlightPhase.tr(
                        context,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      FlightLogsLocalizationKeys.blackBoxApHeadingTarget.tr(
                        context,
                      ),
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
                      FlightLogsLocalizationKeys.blackBoxEngine.tr(context),
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
                      FlightLogsLocalizationKeys.blackBoxEvent.tr(context),
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
                rows: pagePoints.asMap().entries.map((entry) {
                  final localIndex = entry.key;
                  final p = entry.value;
                  final globalIndex = start + localIndex;
                  final eventText = pointEvents[globalIndex];
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
                      DataCell(Text(_formatGSource(p.gForceSource))),
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
                      DataCell(Text(_formatFlightPhase(p.flightPhase))),
                      DataCell(
                        Text(
                          p.autopilotHeadingTarget != null
                              ? p.autopilotHeadingTarget!.toStringAsFixed(0)
                              : '-',
                        ),
                      ),
                      DataCell(
                        Text(
                          '${p.flapsLabel ?? p.flapsPosition?.toString() ?? "-"}/${_formatGearState(p.gearDown)}',
                        ),
                      ),
                      DataCell(
                        Text(
                          '${p.windSpeed?.toStringAsFixed(0) ?? "-"}/${p.windDirection?.toStringAsFixed(0) ?? "-"}',
                        ),
                      ),
                      DataCell(
                        Text(
                          '${_formatPercent(p.engine1N1)}/${_formatPercent(p.engine2N1)} | ${_formatPercent(p.engine1N2)}/${_formatPercent(p.engine2N2)} | ${_formatEgt(p.engine1Egt)}/${_formatEgt(p.engine2Egt)}',
                          style: const TextStyle(fontSize: 10),
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
                          eventText,
                          style: TextStyle(
                            color: eventText == '-'
                                ? null
                                : theme.colorScheme.primary,
                            fontWeight: eventText == '-'
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 760;
                final pageInfo = Text(
                  '${currentPage + 1}/$totalPages',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                );
                final navButtons = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                  ],
                );
                final jumpControls = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 96,
                      child: TextField(
                        controller: _pageJumpController,
                        focusNode: _pageJumpFocusNode,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (value) =>
                            _jumpToPage(totalPages: totalPages, rawPage: value),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: FlightLogsLocalizationKeys
                              .blackBoxJumpToPage
                              .tr(context),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: () => _jumpToPage(
                        totalPages: totalPages,
                        rawPage: _pageJumpController.text,
                      ),
                      child: Text(
                        FlightLogsLocalizationKeys.blackBoxJumpAction.tr(
                          context,
                        ),
                      ),
                    ),
                  ],
                );
                final pageSizeDropdown = DropdownButton<int>(
                  value: rowsPerPage,
                  items: availablePageSizes
                      .map(
                        (size) => DropdownMenuItem<int>(
                          value: size,
                          child: Text(
                            '$size/${FlightLogsLocalizationKeys.blackBoxPageUnit.tr(context)}',
                          ),
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
                );

                if (!isCompact) {
                  return Row(
                    children: [
                      pageInfo,
                      const SizedBox(width: 12),
                      navButtons,
                      jumpControls,
                      const Spacer(),
                      pageSizeDropdown,
                    ],
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [pageInfo, const Spacer(), navButtons]),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: jumpControls,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        pageSizeDropdown,
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatFlightPhase(String? phase) {
    final value = phase?.trim();
    if (value == null || value.isEmpty) {
      return '-';
    }
    return value.toUpperCase();
  }

  String _formatPercent(double? value) {
    if (value == null) {
      return '-';
    }
    return '${value.toStringAsFixed(1)}%';
  }

  String _formatEgt(double? value) {
    if (value == null) {
      return '-';
    }
    return '${value.toStringAsFixed(0)}°C';
  }

  String _formatGSource(LandingGSource source) {
    return source.wireValue;
  }

  String _formatGearState(bool? gearDown) {
    if (gearDown == true) {
      return 'DN';
    }
    if (gearDown == false) {
      return 'UP';
    }
    return '-';
  }

  void _jumpToPage({required int totalPages, required String rawPage}) {
    final target = int.tryParse(rawPage.trim());
    if (target == null) {
      return;
    }
    final normalized = target.clamp(1, totalPages) - 1;
    final displayedPageText = '${normalized + 1}';
    setState(() {
      _currentPage = normalized;
      _pageJumpController.value = TextEditingValue(
        text: displayedPageText,
        selection: TextSelection.collapsed(offset: displayedPageText.length),
      );
    });
    _pageJumpFocusNode.unfocus();
  }

  List<String> _buildPointEvents(BuildContext context, FlightLog log) {
    final labels = List<String>.filled(log.points.length, '-');
    if (log.points.isEmpty) {
      return labels;
    }
    final takeoffLabel = FlightLogsLocalizationKeys.chartEventTakeoff.tr(
      context,
    );
    final touchdownLabel = FlightLogsLocalizationKeys.chartEventTouchdown.tr(
      context,
    );
    final finalTouchdownLabel = FlightLogsLocalizationKeys
        .chartEventFinalTouchdown
        .tr(context);
    final gearDownLabel = FlightLogsLocalizationKeys.chartEventGearDown.tr(
      context,
    );
    final gearUpLabel = FlightLogsLocalizationKeys.chartEventGearUp.tr(context);
    final startLabel = FlightLogsLocalizationKeys.startRecord.tr(context);
    final stopLabel = FlightLogsLocalizationKeys.stopRecord.tr(context);
    labels[0] = startLabel;
    labels[labels.length - 1] = labels.length == 1
        ? '$startLabel / $stopLabel'
        : stopLabel;
    bool? previousGearDown = log.points.first.gearDown;
    for (var i = 1; i < log.points.length; i++) {
      final point = log.points[i];
      final pointLabels = <String>[];
      if (point.gearDown != null &&
          previousGearDown != null &&
          point.gearDown != previousGearDown) {
        pointLabels.add(point.gearDown == true ? gearDownLabel : gearUpLabel);
      }
      if (pointLabels.isNotEmpty) {
        labels[i] = labels[i] == '-'
            ? pointLabels.join(' / ')
            : '${labels[i]} / ${pointLabels.join(' / ')}';
      }
      previousGearDown = point.gearDown ?? previousGearDown;
    }
    final takeoffAt = log.takeoffData?.timestamp;
    if (takeoffAt != null) {
      final takeoffIndex = _nearestPointIndexByTimestamp(log.points, takeoffAt);
      if (takeoffIndex != null) {
        labels[takeoffIndex] = labels[takeoffIndex] == '-'
            ? takeoffLabel
            : '${labels[takeoffIndex]} / $takeoffLabel';
      }
    }
    final touchdownSeq = log.landingData?.touchdownSequence ?? const [];
    final touchdownGs = log.landingData?.touchdownGForces ?? const [];
    if (touchdownSeq.isNotEmpty) {
      for (int i = 0; i < touchdownSeq.length; i++) {
        final touchdownIndex = _nearestPointIndexByTimestamp(
          log.points,
          touchdownSeq[i].timestamp,
        );
        if (touchdownIndex == null) {
          continue;
        }
        final touchdownG = i < touchdownGs.length
            ? touchdownGs[i]
            : touchdownSeq[i].gForce;
        final value =
            '$touchdownLabel ${i + 1} (${touchdownG.toStringAsFixed(2)}G)';
        labels[touchdownIndex] = labels[touchdownIndex] == '-'
            ? value
            : '${labels[touchdownIndex]} / $value';
      }
      final finalTouchdownIndex = _nearestPointIndexByTimestamp(
        log.points,
        log.landingData?.timestamp ?? touchdownSeq.last.timestamp,
      );
      if (finalTouchdownIndex != null) {
        final finalTouchdownG = log.landingData?.gForce;
        final finalTouchdownSource = log.landingData?.gForceSource.wireValue;
        final finalLabel = finalTouchdownG != null
            ? '$finalTouchdownLabel (${finalTouchdownG.toStringAsFixed(2)}G, ${finalTouchdownSource ?? "-"})'
            : finalTouchdownLabel;
        labels[finalTouchdownIndex] = labels[finalTouchdownIndex] == '-'
            ? finalLabel
            : '${labels[finalTouchdownIndex]} / $finalLabel';
      }
    }
    return labels;
  }

  int? _nearestPointIndexByTimestamp(
    List<FlightLogPoint> points,
    DateTime timestamp,
  ) {
    if (points.isEmpty) {
      return null;
    }
    int bestIndex = 0;
    int bestDiff = points.first.timestamp
        .difference(timestamp)
        .inMilliseconds
        .abs();
    for (int i = 1; i < points.length; i++) {
      final diff = points[i].timestamp
          .difference(timestamp)
          .inMilliseconds
          .abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIndex = i;
      }
    }
    return bestIndex;
  }
}
