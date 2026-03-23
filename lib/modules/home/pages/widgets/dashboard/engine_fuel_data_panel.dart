import 'package:flutter/material.dart';
import '../../../../../core/services/localization_service.dart';
import '../../../../../core/theme/app_theme_data.dart';
import '../../../../common/models/common_models.dart';
import '../../../localization/home_localization_keys.dart';
import '../shared/info_chip.dart';

/// 发动机与燃油数据面板，显示 FOB、油耗、N1、EGT（支持单/双发）
class EngineFuelDataPanel extends StatelessWidget {
  /// 当前飞行数据
  final HomeFlightData data;

  const EngineFuelDataPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 若发动机数量 > 1 则显示第二发参数
    final showSecondEngine = (data.numEngines ?? 2) > 1;

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
              Icon(Icons.settings, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                HomeLocalizationKeys.engineTitle.tr(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingMedium),

          // 发动机参数标签列表
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              InfoChip(
                label: HomeLocalizationKeys.engineFob.tr(context),
                value: data.fuelQuantity != null
                    ? '${data.fuelQuantity!.toStringAsFixed(0)} kg'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.engineFf.tr(context),
                value: data.fuelFlow != null
                    ? '${data.fuelFlow!.toStringAsFixed(1)} kg/h'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.engineEng1N1.tr(context),
                value: data.engine1N1 != null
                    ? '${data.engine1N1!.toStringAsFixed(1)}%'
                    : 'N/A',
              ),
              if (showSecondEngine)
                InfoChip(
                  label: HomeLocalizationKeys.engineEng2N1.tr(context),
                  value: data.engine2N1 != null
                      ? '${data.engine2N1!.toStringAsFixed(1)}%'
                      : 'N/A',
                ),
              InfoChip(
                label: HomeLocalizationKeys.engineEng1Egt.tr(context),
                value: data.engine1EGT != null
                    ? '${data.engine1EGT!.toStringAsFixed(0)}°C'
                    : 'N/A',
              ),
              if (showSecondEngine)
                InfoChip(
                  label: HomeLocalizationKeys.engineEng2Egt.tr(context),
                  value: data.engine2EGT != null
                      ? '${data.engine2EGT!.toStringAsFixed(0)}°C'
                      : 'N/A',
                ),
            ],
          ),
        ],
      ),
    );
  }
}
