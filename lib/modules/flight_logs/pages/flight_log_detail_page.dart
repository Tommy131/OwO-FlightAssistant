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

class FlightLogDetailPage extends StatefulWidget {
  final FlightLog log;
  final VoidCallback? onBack;

  const FlightLogDetailPage({super.key, required this.log, this.onBack});

  @override
  State<FlightLogDetailPage> createState() => _FlightLogDetailPageState();
}

class _FlightLogDetailPageState extends State<FlightLogDetailPage> {
  final Set<_DetailSection> _expandedSections = {_DetailSection.track};
  final Set<_DetailSection> _loadedSections = {_DetailSection.track};

  @override
  Widget build(BuildContext context) {
    final log = widget.log;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
        title: Text(
          '${log.aircraftTitle} - ${FlightLogsLocalizationKeys.detailTitle.tr(context)} [${_simulatorLabel(context, log.simulatorLabel)}]',
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
          const SizedBox(width: AppThemeData.spacingMedium),
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
            _buildLazySection(
              _DetailSection.track,
              FlightLogsLocalizationKeys.detailTrack.tr(context),
              () => AnalysisTrackMap(log: widget.log),
            ),
            const SizedBox(height: 12),
            _buildLazySection(
              _DetailSection.profile,
              FlightLogsLocalizationKeys.detailProfile.tr(context),
              () => AnalysisChart(log: widget.log),
            ),
            const SizedBox(height: 12),
            _buildLazySection(
              _DetailSection.blackBox,
              FlightLogsLocalizationKeys.blackBoxTitle.tr(context),
              () => AnalysisBlackBox(log: widget.log),
            ),
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

  Widget _buildLazySection(
    _DetailSection section,
    String title,
    Widget Function() builder,
  ) {
    final theme = Theme.of(context);
    final expanded = _expandedSections.contains(section);
    final loaded = _loadedSections.contains(section);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: ExpansionTile(
        key: ValueKey<String>('flight_log_section_${section.name}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        initiallyExpanded: expanded,
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        onExpansionChanged: (value) {
          setState(() {
            if (value) {
              _expandedSections.add(section);
              _loadedSections.add(section);
              return;
            }
            _expandedSections.remove(section);
          });
        },
        children: [if (loaded) builder() else const SizedBox.shrink()],
      ),
    );
  }

  Widget _buildEventSection(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.log.takeoffData != null)
          Expanded(
            child: _buildEventCard(
              context,
              FlightLogsLocalizationKeys.eventTakeoff.tr(context),
              widget.log.takeoffData!,
              true,
            ),
          ),
        if (widget.log.takeoffData != null && widget.log.landingData != null)
          const SizedBox(width: 16),
        if (widget.log.landingData != null)
          Expanded(
            child: _buildEventCard(
              context,
              FlightLogsLocalizationKeys.eventLanding.tr(context),
              widget.log.landingData!,
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
            _runwayValue(data),
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
            _buildDetailRow(
              FlightLogsLocalizationKeys.approachStability.tr(context),
              _stabilityValue(data),
            ),
            _buildDetailRow(
              FlightLogsLocalizationKeys.flareHeight.tr(context),
              _feetValue(data.flareHeightFt),
            ),
            _buildDetailRow(
              FlightLogsLocalizationKeys.sinkRateAt50.tr(context),
              _sinkRateValue(data.sinkRateAt50FtFpm),
            ),
            _buildDetailRow(
              FlightLogsLocalizationKeys.crosswindTouchdown.tr(context),
              _crosswindValue(data.crosswindAtTouchdownKt),
            ),
            _buildDetailRow(
              FlightLogsLocalizationKeys.bounceCount.tr(context),
              data.bounceCount?.toString() ?? '--',
            ),
          ],
          if (data is TakeoffData) ...[
            _buildDetailRow(
              FlightLogsLocalizationKeys.takeoffStability.tr(context),
              _stabilityValueFromScore(data.takeoffStabilityScore),
            ),
            _buildDetailRow(
              FlightLogsLocalizationKeys.rotationSpeed.tr(context),
              _airspeedValue(data.rotationSpeedKt),
            ),
            _buildDetailRow(
              FlightLogsLocalizationKeys.rotationToLiftoff.tr(context),
              _secondsValue(data.rotationToLiftoffSec),
            ),
            _buildDetailRow(
              FlightLogsLocalizationKeys.crosswindLiftoff.tr(context),
              _crosswindValue(data.crosswindAtLiftoffKt),
            ),
            _buildDetailRow(
              FlightLogsLocalizationKeys.pitchAt35Ft.tr(context),
              _pitchValue(data.pitchAt35FtDeg),
            ),
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
            _remainingRunwayValue(data),
          ),
        ],
      ),
    );
  }

  String _runwayValue(dynamic data) {
    final runway = data.runway;
    if (runway == null || runway.toString().trim().isEmpty) {
      return '--';
    }
    return runway.toString().trim().toUpperCase();
  }

  String _remainingRunwayValue(dynamic data) {
    final value = data.remainingRunwayFt;
    if (value == null || value <= 0) return '--';
    return '${value.toStringAsFixed(0)} ft';
  }

  String _stabilityValue(LandingData data) {
    return _stabilityValueFromScore(data.approachStabilityScore);
  }

  String _stabilityValueFromScore(double? score) {
    if (score == null) return '--';
    return '${score.toStringAsFixed(0)} / 100';
  }

  String _airspeedValue(double? value) {
    if (value == null || value <= 0) return '--';
    return '${value.toStringAsFixed(1)} kts';
  }

  String _secondsValue(int? value) {
    if (value == null || value < 0) return '--';
    return '${value}s';
  }

  String _pitchValue(double? value) {
    if (value == null) return '--';
    return '${value.toStringAsFixed(1)}°';
  }

  String _feetValue(double? value) {
    if (value == null || value <= 0) return '--';
    return '${value.toStringAsFixed(0)} ft';
  }

  String _sinkRateValue(double? value) {
    if (value == null) return '--';
    return '${value.toStringAsFixed(0)} fpm';
  }

  String _crosswindValue(double? value) {
    if (value == null) return '--';
    return '${value.toStringAsFixed(1)} kts';
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

  String _simulatorLabel(BuildContext context, String? simulatorLabel) {
    final normalized = (simulatorLabel ?? '').toUpperCase();
    if (normalized.contains('X-PLANE')) {
      return FlightLogsLocalizationKeys.simulatorXplane.tr(context);
    }
    if (normalized.contains('MSFS')) {
      return FlightLogsLocalizationKeys.simulatorMsfs.tr(context);
    }
    return FlightLogsLocalizationKeys.simulatorUnknown.tr(context);
  }
}

enum _DetailSection { track, profile, blackBox }
