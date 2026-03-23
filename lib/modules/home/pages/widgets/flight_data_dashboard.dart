import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../common/localization/common_localization.dart';
import '../../../common/models/common_models.dart';
import '../../../common/providers/common_provider.dart';
import '../../localization/home_localization_keys.dart';
import 'dashboard/metar_display_widget.dart';
import 'dashboard/primary_flight_data_panel.dart';
import 'dashboard/navigation_data_panel.dart';
import 'dashboard/environment_data_panel.dart';
import 'dashboard/engine_fuel_data_panel.dart';
import 'dashboard/system_status_panel.dart';

/// 飞行数据仪表盘主容器
///
/// 当模拟器已连接时，依次渲染：
/// - 主要飞行参数（空速/高度/航向/垂直速度/油量）
/// - 导航数据（地速/坐标/机型/机场选择）
/// - 环境数据（OAT/TAT/风/QNH/能见度）
/// - 发动机燃油数据（FOB/FF/N1/EGT）
/// - METAR 天气信息
/// - 系统状态面板
///
/// 未连接时显示无信号占位符
class FlightDataDashboard extends StatelessWidget {
  const FlightDataDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<HomeProvider>(
      builder: (context, provider, _) {
        // 未连接时展示占位符
        if (!provider.isConnected) {
          return _buildNoConnectionPlaceholder(context, theme);
        }

        final data = provider.flightData;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 仪表盘标题
            Text(
              HomeLocalizationKeys.dashboardTitle.tr(context),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppThemeData.spacingMedium),

            // 主要飞行参数面板（5卡网格）
            PrimaryFlightDataPanel(data: data),
            const SizedBox(height: AppThemeData.spacingMedium),

            // 导航数据面板（含机场选择器）
            NavigationDataPanel(data: data),
            const SizedBox(height: AppThemeData.spacingMedium),

            // 环境数据面板
            EnvironmentDataPanel(data: data),
            const SizedBox(height: AppThemeData.spacingMedium),

            // 发动机燃油面板
            EngineFuelDataPanel(data: data),
            const SizedBox(height: AppThemeData.spacingMedium),

            // METAR 天气信息区块
            _buildWeatherSection(context, provider),
            const SizedBox(height: AppThemeData.spacingMedium),

            // 系统状态面板（告警/操纵面/起落架/灯光等）
            SystemStatusPanel(data: data),
          ],
        );
      },
    );
  }

  /// 未连接占位符：显示飞机图标和提示文字
  Widget _buildNoConnectionPlaceholder(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppThemeData.spacingLarge * 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemeData.borderRadiusMedium),
        border: Border.all(color: AppThemeData.getBorderColor(theme)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flight_takeoff,
              size: 64,
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              HomeLocalizationKeys.dashboardNoConnectionTitle.tr(context),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              HomeLocalizationKeys.dashboardNoConnectionSubtitle.tr(context),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建 METAR 天气显示区块
  ///
  /// 依次处理当前最近机场、目的地机场、备降机场的 METAR 数据，
  /// 将其按标签分组后交给 [MetarSectionWidget] 渲染
  Widget _buildWeatherSection(BuildContext context, HomeProvider provider) {
    final metars = <String, LiveMetarData>{};
    final errors = <String, String>{};
    final refreshCallbacks = <String, VoidCallback>{};
    final refreshingStates = <String, bool>{};

    // 当前最近机场（作为出发地展示）
    final current = provider.nearestAirport;
    if (current != null) {
      final label =
          '${CommonLocalizationKeys.navDeparture.tr(context)} (${current.icaoCode})';
      final icao = current.icaoCode.trim().toUpperCase();
      if (provider.metarsByIcao.containsKey(icao)) {
        metars[label] = provider.metarsByIcao[icao]!;
      } else if (provider.metarErrorsByIcao.containsKey(icao)) {
        errors[label] = provider.metarErrorsByIcao[icao]!;
      }
      refreshCallbacks[label] = () => provider.refreshMetar(current);
      refreshingStates[label] = provider.metarRefreshingIcaos.contains(icao);
    }

    // 目的地机场
    final dest = provider.destinationAirport;
    if (dest != null) {
      final label =
          '${CommonLocalizationKeys.navDestination.tr(context)} (${dest.icaoCode})';
      final icao = dest.icaoCode.trim().toUpperCase();
      if (provider.metarsByIcao.containsKey(icao)) {
        metars[label] = provider.metarsByIcao[icao]!;
      } else if (provider.metarErrorsByIcao.containsKey(icao)) {
        errors[label] = provider.metarErrorsByIcao[icao]!;
      }
      refreshCallbacks[label] = () => provider.refreshMetar(dest);
      refreshingStates[label] = provider.metarRefreshingIcaos.contains(icao);
    }

    // 备降机场
    final alt = provider.alternateAirport;
    if (alt != null) {
      final label =
          '${CommonLocalizationKeys.navAlternate.tr(context)} (${alt.icaoCode})';
      final icao = alt.icaoCode.trim().toUpperCase();
      if (provider.metarsByIcao.containsKey(icao)) {
        metars[label] = provider.metarsByIcao[icao]!;
      } else if (provider.metarErrorsByIcao.containsKey(icao)) {
        errors[label] = provider.metarErrorsByIcao[icao]!;
      }
      refreshCallbacks[label] = () => provider.refreshMetar(alt);
      refreshingStates[label] = provider.metarRefreshingIcaos.contains(icao);
    }

    return MetarSectionWidget(
      metars: metars,
      errors: errors,
      refreshCallbacks: refreshCallbacks,
      refreshingStates: refreshingStates,
    );
  }
}
