import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/monitor_localization_keys.dart';
import '../../models/monitor_models.dart';

class SystemsStatusCard extends StatelessWidget {
  final MonitorData data;

  const SystemsStatusCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusLarge),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MonitorLocalizationKeys.systemsTitle.tr(context),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          _buildStatusRow(
            context,
            MonitorLocalizationKeys.parkingBrakeLabel.tr(context),
            data.parkingBrake == true
                ? MonitorLocalizationKeys.parkingBrakeSet.tr(context)
                : MonitorLocalizationKeys.parkingBrakeReleased.tr(context),
            isHighlight: data.parkingBrake == true,
            highlightColor: Colors.orangeAccent,
          ),
          const Divider(height: 20),
          _buildStatusRow(
            context,
            MonitorLocalizationKeys.transponderLabel.tr(context),
            _buildTransponderValue(context),
            isHighlight: _isTransponderHighlighted(),
            highlightColor: _getTransponderColor(data.transponderCode),
          ),
          const Divider(height: 20),
          _buildStatusRow(
            context,
            MonitorLocalizationKeys.flapsLabel.tr(context),
            data.flapsLabel ??
                MonitorLocalizationKeys.flapsUp.tr(context),
            isHighlight: (data.flapsDeployRatio ?? 0) > 0.05,
            highlightColor: Colors.blueAccent,
          ),
          const Divider(height: 20),
          _buildStatusRow(
            context,
            MonitorLocalizationKeys.speedBrakeLabel.tr(context),
            data.speedBrakeLabel ??
                MonitorLocalizationKeys.speedBrakeUnknown.tr(context),
            isHighlight: data.speedBrake == true,
            highlightColor: Colors.orangeAccent,
          ),
          if (data.fireWarningEngine1 == true ||
              data.fireWarningEngine2 == true ||
              data.fireWarningAPU == true) ...[
            const Divider(height: 20),
            _buildStatusRow(
              context,
              MonitorLocalizationKeys.fireLabel.tr(context),
              _buildFireWarningValue(context),
              isHighlight: true,
              highlightColor: Colors.redAccent,
            ),
          ],
        ],
      ),
    );
  }

  String _buildTransponderValue(BuildContext context) {
    final code = data.transponderCode;
    final state = data.transponderState;
    if (code != null && code.isNotEmpty) {
      return code;
    }
    if (state != null && state.isNotEmpty) {
      return state;
    }
    return MonitorLocalizationKeys.transponderEmpty.tr(context);
  }

  bool _isTransponderHighlighted() {
    final code = data.transponderCode;
    final state = data.transponderState;
    return _isSpecialTransponder(code) ||
        (state != null && state.isNotEmpty);
  }

  bool _isSpecialTransponder(String? code) {
    if (code == null) return false;
    return code == '7700' || code == '7600' || code == '7500';
  }

  Color _getTransponderColor(String? code) {
    if (code == null) return Colors.blueAccent;
    switch (code) {
      case '7700':
        return Colors.redAccent;
      case '7600':
        return Colors.orangeAccent;
      case '7500':
        return Colors.purpleAccent;
      default:
        return Colors.blueAccent;
    }
  }

  String _buildFireWarningValue(BuildContext context) {
    final labels = <String>[];
    if (data.fireWarningEngine1 == true) {
      labels.add(MonitorLocalizationKeys.fireEngine1.tr(context));
    }
    if (data.fireWarningEngine2 == true) {
      labels.add(MonitorLocalizationKeys.fireEngine2.tr(context));
    }
    if (data.fireWarningAPU == true) {
      labels.add(MonitorLocalizationKeys.fireApu.tr(context));
    }
    final suffix = MonitorLocalizationKeys.fireSuffix.tr(context);
    return '${labels.join(' ')} $suffix';
  }

  Widget _buildStatusRow(
    BuildContext context,
    String label,
    String value, {
    bool isHighlight = false,
    Color highlightColor = Colors.orangeAccent,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color:
                Theme.of(context).textTheme.bodySmall?.color?.withValues(
                      alpha: 0.7,
                    ) ??
                Colors.grey,
            fontSize: 13,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: (isHighlight ? highlightColor : Colors.blueAccent)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: isHighlight ? highlightColor : Colors.blueAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'Monospace',
            ),
          ),
        ),
      ],
    );
  }
}
