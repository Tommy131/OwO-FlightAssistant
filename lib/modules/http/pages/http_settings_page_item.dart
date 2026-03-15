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
  bool _isSaving = false;
  bool _isTesting = false;
  String _currentAddress = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentAddress();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _loadCurrentAddress() {
    final uri = Uri.parse(HttpModule.client.baseUrl);
    final host = uri.host.isNotEmpty ? uri.host : '127.0.0.1';
    final port = uri.hasPort ? uri.port : 18080;
    _hostController.text = host;
    _portController.text = '$port';
    _currentAddress = 'http://$host:$port';
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

  Future<void> _saveAddress(BuildContext context) async {
    final baseUrl = _buildBaseUrl(context);
    if (baseUrl == null) {
      return;
    }
    setState(() {
      _isSaving = true;
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
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _testAddress(BuildContext context) async {
    final baseUrl = _buildBaseUrl(context);
    if (baseUrl == null) {
      return;
    }
    setState(() {
      _isTesting = true;
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
          _isTesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
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
                            HttpLocalizationKeys.backendSectionTitle.tr(
                              context,
                            ),
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
                        onPressed: _isSaving
                            ? null
                            : () => _saveAddress(context),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                        onPressed: _isTesting
                            ? null
                            : () => _testAddress(context),
                        icon: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.wifi_tethering_outlined,
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
        ),
      ],
    );
  }
}
