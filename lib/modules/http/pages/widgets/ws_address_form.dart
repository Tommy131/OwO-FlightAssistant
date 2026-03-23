import 'package:flutter/material.dart';

import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/widgets/common/snack_bar.dart';
import '../../../http/http_module.dart';
import '../../localization/http_localization_keys.dart';

/// WebSocket 地址配置表单卡片
///
/// 提供 WS Host / Port 输入框，支持保存并持久化、WebSocket 端点连通性测试
class WsAddressForm extends StatefulWidget {
  const WsAddressForm({super.key});

  @override
  State<WsAddressForm> createState() => _WsAddressFormState();
}

class _WsAddressFormState extends State<WsAddressForm> {
  final TextEditingController _wsHostController = TextEditingController();
  final TextEditingController _wsPortController = TextEditingController();

  bool _isSaving = false;
  bool _isTesting = false;

  /// 当前 WebSocket 完整地址（只读展示）
  String _currentWsAddress = '';

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _wsHostController.dispose();
    _wsPortController.dispose();
    super.dispose();
  }

  /// 从服务读取当前 WebSocket 地址并填充输入框
  void _loadCurrent() {
    final httpUri = Uri.parse(HttpModule.client.baseUrl);
    final wsUri = Uri.parse(HttpModule.client.webSocketBaseUrl);
    final fallbackHost = httpUri.host.isNotEmpty ? httpUri.host : '127.0.0.1';
    final wsHost = wsUri.host.isNotEmpty ? wsUri.host : fallbackHost;
    final wsPort = wsUri.hasPort ? wsUri.port : 18081;
    _wsHostController.text = wsHost;
    _wsPortController.text = '$wsPort';
    _currentWsAddress = 'ws://$wsHost:$wsPort/api/v1/simulator/ws';
  }

  /// 根据输入框内容构建 wsBaseUrl，输入非法时显示错误并返回 null
  String? _buildWsBaseUrl(BuildContext context) {
    final host = _wsHostController.text.trim();
    final portText = _wsPortController.text.trim();
    if (host.isEmpty || host.contains(' ')) {
      SnackBarHelper.showError(
        context,
        HttpLocalizationKeys.invalidHost.tr(context),
      );
      return null;
    }
    final port = int.tryParse(portText);
    if (port == null || port < 1 || port > 65535) {
      SnackBarHelper.showError(
        context,
        HttpLocalizationKeys.invalidPort.tr(context),
      );
      return null;
    }
    return 'ws://$host:$port/api/v1/simulator/ws';
  }

  /// 保存 WebSocket 地址并持久化
  Future<void> _save(BuildContext context) async {
    final wsBaseUrl = _buildWsBaseUrl(context);
    if (wsBaseUrl == null) return;
    setState(() => _isSaving = true);
    try {
      await HttpModule.client.configure(
        webSocketBaseUrl: wsBaseUrl,
        persist: true,
      );
      if (!mounted) return;
      setState(() => _currentWsAddress = wsBaseUrl);
      SnackBarHelper.showSuccess(
        context,
        HttpLocalizationKeys.saveSuccess.tr(context),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 临时切换地址并测试 WebSocket 端点（GET /api/v1/simulator/ws），不持久化
  Future<void> _test(BuildContext context) async {
    final wsBaseUrl = _buildWsBaseUrl(context);
    if (wsBaseUrl == null) return;
    setState(() => _isTesting = true);
    try {
      await HttpModule.client.configure(
        webSocketBaseUrl: wsBaseUrl,
        persist: false,
      );
      await HttpModule.client.getSimulatorWebSocketInfo();
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        HttpLocalizationKeys.testSuccess.tr(context),
      );
    } on MiddlewareHttpException catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        '${HttpLocalizationKeys.testFailed.tr(context)}: ${e.message}',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        '${HttpLocalizationKeys.testFailed.tr(context)}: $e',
      );
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 区块标题行（图标 + 标题 + 描述）
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppThemeData.borderRadiusSmall,
                    ),
                  ),
                  child: Icon(
                    Icons.wifi_tethering_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        HttpLocalizationKeys.wsSectionTitle.tr(context),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        HttpLocalizationKeys.wsSectionDescription.tr(context),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppThemeData.spacingMedium),

            // WS Host 输入框
            TextField(
              controller: _wsHostController,
              decoration: InputDecoration(
                labelText: HttpLocalizationKeys.wsHostLabel.tr(context),
                hintText: HttpLocalizationKeys.wsHostHint.tr(context),
                prefixIcon: const Icon(Icons.wifi_outlined),
              ),
            ),
            const SizedBox(height: AppThemeData.spacingSmall),

            // WS Port 输入框
            TextField(
              controller: _wsPortController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: HttpLocalizationKeys.wsPortLabel.tr(context),
                hintText: HttpLocalizationKeys.wsPortHint.tr(context),
                prefixIcon: const Icon(Icons.settings_ethernet_outlined),
              ),
            ),
            const SizedBox(height: AppThemeData.spacingSmall),

            // 当前地址只读展示
            Text(
              HttpLocalizationKeys.currentWsAddress
                  .tr(context)
                  .replaceFirst('{address}', _currentWsAddress),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppThemeData.spacingMedium),

            // 保存 / 测试 按钮行
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _save(context),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _isSaving
                          ? HttpLocalizationKeys.saving.tr(context)
                          : HttpLocalizationKeys.saveButton.tr(context),
                    ),
                  ),
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : () => _test(context),
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering_outlined, size: 18),
                    label: Text(
                      _isTesting
                          ? HttpLocalizationKeys.testing.tr(context)
                          : HttpLocalizationKeys.testButton.tr(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
