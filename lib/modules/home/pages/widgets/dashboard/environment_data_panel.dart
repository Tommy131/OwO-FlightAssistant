import 'package:flutter/material.dart';
import '../../../../../core/services/localization_service.dart';
import '../../../../../core/theme/app_theme_data.dart';
import '../../../../common/models/common_models.dart';
import '../../../localization/home_localization_keys.dart';
import '../shared/info_chip.dart';

/// 环境数据面板，显示 OAT、TAT、风向风速、QNH 气压、能见度
class EnvironmentDataPanel extends StatelessWidget {
  /// 当前飞行数据
  final HomeFlightData data;

  const EnvironmentDataPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(color: AppThemeData.getBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 面板标题
          Row(
            children: [
              Icon(Icons.wb_sunny, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                HomeLocalizationKeys.environmentTitle.tr(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingMedium),

          // 环境数据标签列表
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              InfoChip(
                label: HomeLocalizationKeys.environmentOat.tr(context),
                value: data.outsideAirTemperature != null
                    ? '${data.outsideAirTemperature!.toStringAsFixed(1)} °C'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.environmentTat.tr(context),
                value: data.totalAirTemperature != null
                    ? '${data.totalAirTemperature!.toStringAsFixed(1)} °C'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.environmentWind.tr(context),
                value: (data.windSpeed != null && data.windDirection != null)
                    ? '${data.windDirection!.toStringAsFixed(0)}° / ${data.windSpeed!.toStringAsFixed(0)} kt'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.environmentQnh.tr(context),
                value: data.baroPressure != null
                    ? '${data.baroPressure!.toStringAsFixed(2)} ${data.baroPressureUnit ?? "inHg"}'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.environmentVisibility.tr(context),
                value: data.visibility != null
                    ? (data.visibility! >= 9999
                          ? '> 10 km'
                          : data.visibility! >= 1000
                          ? '${(data.visibility! / 1000).toStringAsFixed(1)} km'
                          : '${data.visibility!.toStringAsFixed(0)} m')
                    : 'N/A',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
