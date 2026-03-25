import 'package:flutter/material.dart';
import '../../../../../core/services/localization_service.dart';
import '../../../../../core/theme/app_theme_data.dart';
import '../../../../common/localization/common_localization.dart';
import '../../../../common/models/common_models.dart';
import '../../../localization/home_localization_keys.dart';
import '../airport/airport_picker_dialog.dart';
import '../shared/info_chip.dart';

/// 导航与位置数据面板，显示地速、真空速、坐标、机型、出发/目的地/备降机场
/// 并提供机场选择器入口
class NavigationDataPanel extends StatelessWidget {
  /// 当前飞行数据
  final HomeFlightData data;

  const NavigationDataPanel({super.key, required this.data});

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
          // 面板标题行
          Row(
            children: [
              Icon(Icons.map, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                HomeLocalizationKeys.navTitle.tr(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeData.spacingMedium),

          // 导航参数标签列表
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              InfoChip(
                label: HomeLocalizationKeys.navGroundSpeed.tr(context),
                value: data.groundSpeed != null
                    ? '${data.groundSpeed!.toStringAsFixed(0)} kt'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.navTrueAirspeed.tr(context),
                value: data.trueAirspeed != null
                    ? '${data.trueAirspeed!.toStringAsFixed(0)} kt'
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.navLatitude.tr(context),
                value: data.latitude != null
                    ? data.latitude!.toStringAsFixed(4)
                    : 'N/A',
              ),
              InfoChip(
                label: HomeLocalizationKeys.navLongitude.tr(context),
                value: data.longitude != null
                    ? data.longitude!.toStringAsFixed(4)
                    : 'N/A',
              ),
              // 优先展示 displayName，再 fallback 到 model
              if ((data.aircraftDisplayName ?? '').trim().isNotEmpty)
                InfoChip(
                  label: HomeLocalizationKeys.navAircraft.tr(context),
                  value: data.aircraftDisplayName!,
                )
              else if ((data.aircraftModel ?? '').trim().isNotEmpty)
                InfoChip(
                  label: HomeLocalizationKeys.navAircraft.tr(context),
                  value: data.aircraftModel!,
                ),
              if ((data.aircraftIcao ?? '').trim().isNotEmpty)
                InfoChip(
                  label: HomeLocalizationKeys.navAircraftIcao.tr(context),
                  value: data.aircraftIcao!,
                ),
              if (data.departureAirport != null)
                InfoChip(
                  label: CommonLocalizationKeys.navDeparture.tr(context),
                  value: data.departureAirport!,
                ),
              if (data.arrivalAirport != null)
                InfoChip(
                  label: HomeLocalizationKeys.navArrival.tr(context),
                  value: data.arrivalAirport!,
                ),
            ],
          ),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 660;
              final frequencyWidget = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.settings_input_antenna,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${HomeLocalizationKeys.navCom1.tr(context)}:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    data.com1Frequency != null
                        ? '${data.com1Frequency!.toStringAsFixed(2)} MHz'
                        : 'N/A',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'Monospace',
                    ),
                  ),
                ],
              );
              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    frequencyWidget,
                    const SizedBox(height: AppThemeData.spacingSmall),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: AirportPickerButtonGroup(direction: Axis.vertical),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: frequencyWidget),
                  const SizedBox(width: AppThemeData.spacingSmall),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: AirportPickerButtonGroup(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
