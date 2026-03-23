import 'package:flutter/material.dart';

import '../../../core/module_registry/settings_page/settings_page_item.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../localization/http_localization_keys.dart';
import 'widgets/diagnosis_form.dart';
import 'widgets/http_address_form.dart';
import 'widgets/runtime_settings_form.dart';
import 'widgets/ws_address_form.dart';

/// HTTP 后端设置页注册项
///
/// 注册到全局 SettingsPageRegistry，在设置页侧边栏显示为"后端连接"选项
class HttpSettingsPageItem extends SettingsPageItem {
  @override
  String get id => 'http_backend_settings';

  @override
  String getTitle(BuildContext context) =>
      HttpLocalizationKeys.settingsTitle.tr(context);

  @override
  IconData get icon => Icons.cloud_outlined;

  @override
  int get priority => 80;

  @override
  String getDescription(BuildContext context) =>
      HttpLocalizationKeys.settingsDescription.tr(context);

  @override
  Widget build(BuildContext context) {
    return const _HttpBackendSettingsView();
  }
}

/// HTTP 后端设置页主视图
///
/// 作为薄编排层，将四个独立表单模块组合展示：
/// - [HttpAddressForm]      — HTTP 地址配置
/// - [WsAddressForm]        — WebSocket 地址配置
/// - [RuntimeSettingsForm]  — 运行时性能参数
/// - [DiagnosisForm]        — 连接诊断工具
class _HttpBackendSettingsView extends StatelessWidget {
  const _HttpBackendSettingsView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        HttpAddressForm(),
        SizedBox(height: AppThemeData.spacingMedium),
        WsAddressForm(),
        SizedBox(height: AppThemeData.spacingMedium),
        RuntimeSettingsForm(),
        SizedBox(height: AppThemeData.spacingMedium),
        DiagnosisForm(),
      ],
    );
  }
}
