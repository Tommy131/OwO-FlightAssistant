import 'package:flutter/material.dart';

import '../../../core/module_registry/settings_page/settings_page_item.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/snack_bar.dart';
import '../http_module.dart';
import '../localization/http_localization_keys.dart';

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

class _HttpBackendSettingsView extends StatefulWidget {
  const _HttpBackendSettingsView();

  @override
  State<_HttpBackendSettingsView> createState() =>
      _HttpBackendSettingsViewState();
}

class _HttpBackendSettingsViewState extends State<_HttpBackendSettingsView> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _wsHostController = TextEditingController();
  final TextEditingController _wsPortController = TextEditingController();
  bool _isHttpSaving = false;
  bool _isHttpTesting = false;
  bool _isWsSaving = false;
  bool _isWsTesting = false;
  String _currentAddress = '';
  String _currentWsAddress = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentAddress();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _wsHostController.dispose();
    _wsPortController.dispose();
    super.dispose();
  }

  void _loadCurrentAddress() {
    final uri = Uri.parse(HttpModule.client.baseUrl);
    final wsUri = Uri.parse(HttpModule.client.webSocketBaseUrl);
    final host = uri.host.isNotEmpty ? uri.host : '127.0.0.1';
    final port = uri.hasPort ? uri.port : 18080;
    final wsHost = wsUri.host.isNotEmpty ? wsUri.host : host;
    final wsPort = wsUri.hasPort ? wsUri.port : 18081;
    _hostController.text = host;
    _portController.text = '$port';
    _wsHostController.text = wsHost;
    _wsPortController.text = '$wsPort';
    _currentAddress = 'http://$host:$port';
    _currentWsAddress = 'ws://$wsHost:$wsPort/api/v1/simulator/ws';
  }

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

  Future<void> _saveHttpAddress(BuildContext context) async {
    final baseUrl = _buildBaseUrl(context);
    if (baseUrl == null) {
      return;
    }
    setState(() {
      _isHttpSaving = true;
    });
    try {
      await HttpModule.client.configure(baseUrl: baseUrl, persist: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentAddress = baseUrl;
      });
      SnackBarHelper.showSuccess(
        context,
        HttpLocalizationKeys.saveSuccess.tr(context),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isHttpSaving = false;
        });
      }
    }
  }

  Future<void> _testHttpAddress(BuildContext context) async {
    final baseUrl = _buildBaseUrl(context);
    if (baseUrl == null) {
      return;
    }
    setState(() {
      _isHttpTesting = true;
    });
    try {
      await HttpModule.client.configure(baseUrl: baseUrl, persist: false);
      await HttpModule.client.getHealth();
      if (!mounted) {
        return;
      }
      SnackBarHelper.showSuccess(
        context,
        HttpLocalizationKeys.testSuccess.tr(context),
      );
    } on MiddlewareHttpException catch (e) {
      if (!mounted) {
        return;
      }
      SnackBarHelper.showError(
        context,
        '${HttpLocalizationKeys.testFailed.tr(context)}: ${e.message}',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      SnackBarHelper.showError(
        context,
        '${HttpLocalizationKeys.testFailed.tr(context)}: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isHttpTesting = false;
        });
      }
    }
  }

  Future<void> _saveWsAddress(BuildContext context) async {
    final wsBaseUrl = _buildWsBaseUrl(context);
    if (wsBaseUrl == null) {
      return;
    }
    setState(() {
      _isWsSaving = true;
    });
    try {
      await HttpModule.client.configure(
        webSocketBaseUrl: wsBaseUrl,
        persist: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _currentWsAddress = wsBaseUrl;
      });
      SnackBarHelper.showSuccess(
        context,
        HttpLocalizationKeys.saveSuccess.tr(context),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWsSaving = false;
        });
      }
    }
  }

  Future<void> _testWsAddress(BuildContext context) async {
    final wsBaseUrl = _buildWsBaseUrl(context);
    if (wsBaseUrl == null) {
      return;
    }
    setState(() {
      _isWsTesting = true;
    });
    try {
      await HttpModule.client.configure(
        webSocketBaseUrl: wsBaseUrl,
        persist: false,
      );
      await HttpModule.client.getSimulatorWebSocketInfo();
      if (!mounted) {
        return;
      }
      SnackBarHelper.showSuccess(
        context,
        HttpLocalizationKeys.testSuccess.tr(context),
      );
    } on MiddlewareHttpException catch (e) {
      if (!mounted) {
        return;
      }
      SnackBarHelper.showError(
        context,
        '${HttpLocalizationKeys.testFailed.tr(context)}: ${e.message}',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      SnackBarHelper.showError(
        context,
        '${HttpLocalizationKeys.testFailed.tr(context)}: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWsTesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHttpForm(context),
        const SizedBox(height: AppThemeData.spacingMedium),
        _buildWsForm(context),
      ],
    );
  }

  Widget _buildHttpForm(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            TextField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: HttpLocalizationKeys.hostLabel.tr(context),
                hintText: HttpLocalizationKeys.hostHint.tr(context),
                prefixIcon: const Icon(Icons.language_outlined),
              ),
            ),
            const SizedBox(height: AppThemeData.spacingSmall),
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
            Text(
              HttpLocalizationKeys.currentAddress
                  .tr(context)
                  .replaceFirst('{address}', _currentAddress),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isHttpSaving
                        ? null
                        : () => _saveHttpAddress(context),
                    icon: _isHttpSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _isHttpSaving
                          ? HttpLocalizationKeys.saving.tr(context)
                          : HttpLocalizationKeys.saveButton.tr(context),
                    ),
                  ),
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isHttpTesting
                        ? null
                        : () => _testHttpAddress(context),
                    icon: _isHttpTesting
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
                      _isHttpTesting
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

  Widget _buildWsForm(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            TextField(
              controller: _wsHostController,
              decoration: InputDecoration(
                labelText: HttpLocalizationKeys.wsHostLabel.tr(context),
                hintText: HttpLocalizationKeys.wsHostHint.tr(context),
                prefixIcon: const Icon(Icons.wifi_outlined),
              ),
            ),
            const SizedBox(height: AppThemeData.spacingSmall),
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
            Text(
              HttpLocalizationKeys.currentWsAddress
                  .tr(context)
                  .replaceFirst('{address}', _currentWsAddress),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isWsSaving
                        ? null
                        : () => _saveWsAddress(context),
                    icon: _isWsSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _isWsSaving
                          ? HttpLocalizationKeys.saving.tr(context)
                          : HttpLocalizationKeys.saveButton.tr(context),
                    ),
                  ),
                ),
                const SizedBox(width: AppThemeData.spacingSmall),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isWsTesting
                        ? null
                        : () => _testWsAddress(context),
                    icon: _isWsTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering_outlined, size: 18),
                    label: Text(
                      _isWsTesting
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
