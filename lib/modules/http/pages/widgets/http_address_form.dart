import 'package:flutter/material.dart';

import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/widgets/common/snack_bar.dart';
import '../../../http/http_module.dart';
import '../../localization/http_localization_keys.dart';

/// HTTP 后端地址配置表单卡片
///
/// 提供 Host / Port 输入框，支持保存并持久化、连通性测试（GET /health）
class HttpAddressForm extends StatefulWidget {
  const HttpAddressForm({super.key});

  @override
  State<HttpAddressForm> createState() => _HttpAddressFormState();
}

class _HttpAddressFormState extends State<HttpAddressForm> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  bool _isSaving = false;
  bool _isTesting = false;

  /// 当前展示的完整地址（仅用于只读显示）
  String _currentAddress = '';

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  /// 从服务实例读取当前地址并填充输入框
  void _loadCurrent() {
    final uri = Uri.parse(HttpModule.client.baseUrl);
    final host = uri.host.isNotEmpty ? uri.host : '127.0.0.1';
    final port = uri.hasPort ? uri.port : 18080;
    _hostController.text = host;
    _portController.text = '$port';
    _currentAddress = 'http://$host:$port';
  }

  /// 根据输入框内容构建 baseUrl，输入非法时显示错误提示并返回 null
  String? _buildBaseUrl(BuildContext context) {
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();
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
    return 'http://$host:$port';
  }

  /// 保存 HTTP 地址并持久化到本地存储
  Future<void> _save(BuildContext context) async {
    final baseUrl = _buildBaseUrl(context);
    if (baseUrl == null) return;
    setState(() => _isSaving = true);
    try {
      await HttpModule.client.configure(baseUrl: baseUrl, persist: true);
      if (!mounted) return;
      setState(() => _currentAddress = baseUrl);
      SnackBarHelper.showSuccess(
        context,
        HttpLocalizationKeys.saveSuccess.tr(context),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 临时切换地址并测试连通性（GET /health），测试后不持久化
  Future<void> _test(BuildContext context) async {
    final baseUrl = _buildBaseUrl(context);
    if (baseUrl == null) return;
    setState(() => _isTesting = true);
    try {
      await HttpModule.client.configure(baseUrl: baseUrl, persist: false);
      await HttpModule.client.getHealth();
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
                    Icons.router_outlined,
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
                        HttpLocalizationKeys.backendSectionTitle.tr(context),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        HttpLocalizationKeys.backendSectionDescription.tr(
                          context,
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppThemeData.spacingMedium),

            // Host 输入框
            TextField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: HttpLocalizationKeys.hostLabel.tr(context),
                hintText: HttpLocalizationKeys.hostHint.tr(context),
                prefixIcon: const Icon(Icons.language_outlined),
              ),
            ),
            const SizedBox(height: AppThemeData.spacingSmall),

            // Port 输入框
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: HttpLocalizationKeys.portLabel.tr(context),
                hintText: HttpLocalizationKeys.portHint.tr(context),
                prefixIcon: const Icon(Icons.settings_ethernet_outlined),
              ),
            ),
            const SizedBox(height: AppThemeData.spacingSmall),

            // 当前地址只读展示
            Text(
              HttpLocalizationKeys.currentAddress
                  .tr(context)
                  .replaceFirst('{address}', _currentAddress),
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
                        : const Icon(
                            Icons.health_and_safety_outlined,
                            size: 18,
                          ),
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
