import 'package:flutter/material.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../localization/monitor_localization_keys.dart';
import '../../models/monitor_models.dart';

class MonitorHeader extends StatelessWidget {
  final MonitorData data;

  const MonitorHeader({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.masterWarning == true || data.masterCaution == true)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppThemeData.spacingMedium),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: (data.masterWarning == true ? Colors.red : Colors.orange)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusMedium,
              ),
              border: Border.all(
                color: (data.masterWarning == true ? Colors.red : Colors.orange)
                    .withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  data.masterWarning == true ? Icons.warning : Icons.info,
                  color:
                      data.masterWarning == true ? Colors.red : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data.masterWarning == true
                        ? MonitorLocalizationKeys.masterWarningMessage.tr(
                            context,
                          )
                        : MonitorLocalizationKeys.masterCautionMessage.tr(
                            context,
                          ),
                    style: TextStyle(
                      color: data.masterWarning == true
                          ? Colors.red
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MonitorLocalizationKeys.pageTitle.tr(context),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  data.isConnected
                      ? MonitorLocalizationKeys.pageSubtitleConnected.tr(
                          context,
                        )
                      : MonitorLocalizationKeys.pageSubtitleDisconnected.tr(
                          context,
                        ),
                  style: TextStyle(color: theme.hintColor),
                ),
              ],
            ),
            if (data.isConnected && data.isPaused == true)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pause, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      MonitorLocalizationKeys.pausedLabel.tr(context),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
