import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/services/localization_service.dart';
import '../../../../../core/theme/app_theme_data.dart';
import '../../../../common/models/common_models.dart';
import '../../../../common/providers/common_provider.dart';
import '../../../localization/home_localization_keys.dart';
import '../shared/data_card.dart';

/// 主要飞行参数面板，展示空速、高度、航向、垂直速度、油量状态共5个核心数据卡
class PrimaryFlightDataPanel extends StatelessWidget {
  /// 当前飞行数据
  final HomeFlightData data;

  const PrimaryFlightDataPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isFuelOk = context.watch<HomeProvider>().isFuelSufficient;

    // 油量状态标签与颜色
    final fuelStatusLabel = isFuelOk == null
        ? HomeLocalizationKeys.primaryFuelUnknown.tr(context)
        : isFuelOk
        ? HomeLocalizationKeys.primaryFuelOk.tr(context)
        : HomeLocalizationKeys.primaryFuelLow.tr(context);
    final fuelColor = isFuelOk == null
        ? Colors.grey
        : isFuelOk
        ? Colors.teal
        : Colors.red;

    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppThemeData.spacingSmall,
      mainAxisSpacing: AppThemeData.spacingMedium,
      childAspectRatio: 1.1,
      children: [
        DataCard(
          icon: Icons.speed,
          label: HomeLocalizationKeys.primaryAirspeed.tr(context),
          value: data.airspeed != null
              ? '${data.airspeed!.toStringAsFixed(0)} kt'
              : 'N/A',
          subValue: data.machNumber != null && data.machNumber! > 0.1
              ? 'M ${data.machNumber!.toStringAsFixed(3)}'
              : null,
          color: Colors.blue,
        ),
        DataCard(
          icon: Icons.height,
          label: HomeLocalizationKeys.primaryAltitude.tr(context),
          value: data.altitude != null
              ? '${data.altitude!.toStringAsFixed(0)} ft'
              : 'N/A',
          color: Colors.green,
        ),
        DataCard(
          icon: Icons.explore,
          label: HomeLocalizationKeys.primaryHeading.tr(context),
          value: data.heading != null
              ? '${data.heading!.toStringAsFixed(0)}°'
              : 'N/A',
          color: Colors.purple,
        ),
        DataCard(
          icon: Icons.trending_up,
          label: HomeLocalizationKeys.primaryVerticalSpeed.tr(context),
          value: data.verticalSpeed != null
              ? '${data.verticalSpeed!.toStringAsFixed(0)} fpm'
              : 'N/A',
          color: Colors.orange,
        ),
        DataCard(
          icon: Icons.local_gas_station,
          label: HomeLocalizationKeys.primaryFuelStatus.tr(context),
          value: fuelStatusLabel,
          color: fuelColor,
        ),
      ],
    );
  }
}
