// 地图模块设置页入口
//
// 职责：仅负责注册 SettingsPageItem 元数据，并将各独立区块组件组装成设置页面。
// 业务逻辑和状态管理已全部下沉到各区块组件中：
// - [MapHomeAirportSection]   → settings/map_home_airport_section.dart
// - [MapAlertSettingsSection] → settings/map_alert_settings_section.dart
// - [MapTimerSettingsSection] → settings/map_timer_settings_section.dart

import 'package:flutter/material.dart';

import '../../../core/module_registry/settings_page/settings_page_item.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../localization/map_localization_keys.dart';
import 'widgets/settings/map_alert_settings_section.dart';
import 'widgets/settings/map_home_airport_section.dart';
import 'widgets/settings/map_timer_settings_section.dart';

/// 地图模块设置页注册项
///
/// 实现 [SettingsPageItem] 接口，向设置页面注册表提供元数据（id、标题、图标、优先级等），
/// 并构建对应的设置页面 Widget。
class MapModuleSettingsPageItem extends SettingsPageItem {
  @override
  String get id => 'map_module_settings';

  @override
  String getTitle(BuildContext context) =>
      MapLocalizationKeys.moduleSettings.tr(context);

  @override
  IconData get icon => Icons.map_outlined;

  @override
  int get priority => 70;

  @override
  String getDescription(BuildContext context) =>
      MapLocalizationKeys.moduleSettingsDesc.tr(context);

  @override
  Widget build(BuildContext context) {
    return const _MapModuleSettingsView();
  }
}

/// 地图模块设置页主视图
///
/// 纯组装层：按垂直顺序排列三个独立配置区块。
/// 每个区块完全自洽，不依赖父级 State 或向上传递状态。
class _MapModuleSettingsView extends StatelessWidget {
  const _MapModuleSettingsView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 本机机场配置区块
        MapHomeAirportSection(),
        SizedBox(height: AppThemeData.spacingMedium),
        // 飞行警报配置区块
        MapAlertSettingsSection(),
        SizedBox(height: AppThemeData.spacingMedium),
        // 自动 HUD 计时器配置区块
        MapTimerSettingsSection(),
      ],
    );
  }
}
