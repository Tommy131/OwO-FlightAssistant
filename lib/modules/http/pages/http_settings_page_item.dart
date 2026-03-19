import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/module_registry/settings_page/settings_page_item.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/services/persistence_service.dart';
import '../../../core/theme/app_theme_data.dart';
import '../../../core/widgets/common/snack_bar.dart';
import '../../flight_logs/providers/flight_logs_provider.dart';
import '../../home/models/home_models.dart';
import '../../home/providers/home_provider.dart';
import '../../map/providers/map_provider.dart';
import '../../monitor/providers/monitor_provider.dart';
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
  final TextEditingController _flightDataIntervalController =
      TextEditingController();
  final TextEditingController _flightLogIntervalController =
      TextEditingController();
  final TextEditingController _uiRefreshIntervalController =
      TextEditingController();
  bool _isHttpSaving = false;
  bool _isHttpTesting = false;
  bool _isWsSaving = false;
  bool _isWsTesting = false;
  bool _isDiagnosing = false;
  bool _isSavingSettings = false;
  bool _lowPerformanceMode = false;
  String _currentAddress = '';
  String _currentWsAddress = '';
  int _currentFlightDataInterval = 300;
  int _currentFlightLogInterval = FlightLogsProvider.defaultSampleIntervalMs;
  int _currentUiRefreshInterval = 120;
  List<String> _diagnosisMessages = const [];

  static const String _performanceModuleName = 'performance';
  static const String _lowPerformanceModeKey = 'low_performance_mode';
  static const String _uiRefreshIntervalMsKey = 'ui_refresh_interval_ms';
  static const int _lowPerformanceIntervalMs = 500;

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
    _flightDataIntervalController.dispose();
    _flightLogIntervalController.dispose();
    _uiRefreshIntervalController.dispose();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadRuntimeSettings();
    });
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

  Future<void> _loadRuntimeSettings() async {
    final homeProvider = context.read<HomeProvider>();
    final logsProvider = context.read<FlightLogsProvider>();
    final persistence = PersistenceService();
    await persistence.ensureReady();
    final flightDataInterval = await homeProvider.getFlightDataIntervalMs();
    final uiRefreshInterval =
        persistence.getModuleData<int>(
          _performanceModuleName,
          _uiRefreshIntervalMsKey,
        ) ??
        120;
    final lowPerformance =
        persistence.getModuleData<bool>(
          _performanceModuleName,
          _lowPerformanceModeKey,
        ) ??
        false;
    if (!mounted) return;
    setState(() {
      _currentFlightDataInterval = flightDataInterval;
      _currentFlightLogInterval = logsProvider.sampleIntervalMs;
      _currentUiRefreshInterval = uiRefreshInterval.clamp(60, 2000).toInt();
      _lowPerformanceMode = lowPerformance;
      _flightDataIntervalController.text = '$flightDataInterval';
      _flightLogIntervalController.text = '${logsProvider.sampleIntervalMs}';
      _uiRefreshIntervalController.text = '$_currentUiRefreshInterval';
    });
  }

  Future<void> _saveRuntimeSettings(BuildContext context) async {
    final flightDataInterval = int.tryParse(
      _flightDataIntervalController.text.trim(),
    );
    final flightLogInterval = int.tryParse(
      _flightLogIntervalController.text.trim(),
    );
    final uiRefreshInterval = int.tryParse(
      _uiRefreshIntervalController.text.trim(),
    );
    if (flightDataInterval == null ||
        flightDataInterval < 100 ||
        flightDataInterval > 2000) {
      SnackBarHelper.showError(
        context,
        HttpLocalizationKeys.invalidFlightDataInterval.tr(context),
      );
      return;
    }
    if (flightLogInterval == null ||
        flightLogInterval < FlightLogsProvider.minSampleIntervalMs ||
        flightLogInterval > FlightLogsProvider.maxSampleIntervalMs) {
      SnackBarHelper.showError(
        context,
        HttpLocalizationKeys.invalidFlightLogInterval.tr(context),
      );
      return;
    }
    if (uiRefreshInterval == null ||
        uiRefreshInterval < 60 ||
        uiRefreshInterval > 2000) {
      SnackBarHelper.showError(
        context,
        HttpLocalizationKeys.invalidUiRefreshInterval.tr(context),
      );
      return;
    }
    setState(() {
      _isSavingSettings = true;
    });
    try {
      final homeProvider = context.read<HomeProvider>();
      final logsProvider = context.read<FlightLogsProvider>();
      final monitorProvider = context.read<MonitorProvider>();
      final mapProvider = context.read<MapProvider>();
      final persistence = PersistenceService();
      await persistence.ensureReady();
      await homeProvider.setFlightDataIntervalMs(flightDataInterval);
      await logsProvider.setSampleIntervalMs(flightLogInterval);
      await persistence.setModuleData(
        _performanceModuleName,
        _lowPerformanceModeKey,
        _lowPerformanceMode,
      );
      await persistence.setModuleData(
        _performanceModuleName,
        _uiRefreshIntervalMsKey,
        uiRefreshInterval,
      );
      await monitorProvider.refreshPerformanceSettings();
      await mapProvider.refreshPerformanceSettings();
      if (!mounted) return;
      setState(() {
        _currentFlightDataInterval = flightDataInterval;
        _currentFlightLogInterval = flightLogInterval;
        _currentUiRefreshInterval = uiRefreshInterval;
      });
      SnackBarHelper.showSuccess(
        context,
        HttpLocalizationKeys.flightDataIntervalSaved.tr(context),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingSettings = false;
        });
      }
    }
  }

  Future<void> _runDiagnosis(BuildContext context) async {
    setState(() {
      _isDiagnosing = true;
      _diagnosisMessages = const [];
    });
    final homeProvider = context.read<HomeProvider>();
    final checks = <String>[];
    try {
      await HttpModule.client.init();
      try {
        await HttpModule.client.getHealth();
        checks.add('✅ ${HttpLocalizationKeys.diagnoseBackendOk.tr(context)}');
      } catch (e) {
        checks.add(
          '❌ ${HttpLocalizationKeys.diagnoseBackendFail.tr(context)}: $e',
        );
      }
      try {
        await HttpModule.client.getSimulatorWebSocketInfo();
        checks.add('✅ ${HttpLocalizationKeys.diagnoseWsOk.tr(context)}');
      } catch (e) {
        checks.add('❌ ${HttpLocalizationKeys.diagnoseWsFail.tr(context)}: $e');
      }
      if (homeProvider.isConnected) {
        checks.add('✅ ${HttpLocalizationKeys.diagnoseTokenOk.tr(context)}');
      } else {
        checks.add('❌ ${HttpLocalizationKeys.diagnoseTokenFail.tr(context)}');
      }
      final simulatorType = _diagnosisSimulatorType(homeProvider);
      try {
        await HttpModule.client.getSimulatorState(type: simulatorType);
        checks.add('✅ ${HttpLocalizationKeys.diagnoseSimulatorOk.tr(context)}');
      } catch (e) {
        checks.add(
          '❌ ${HttpLocalizationKeys.diagnoseSimulatorFail.tr(context)}: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDiagnosing = false;
          _diagnosisMessages = checks;
        });
      }
    }
  }

  String _diagnosisSimulatorType(HomeProvider provider) {
    return switch (provider.simulatorType) {
      HomeSimulatorType.msfs => 'msfs',
      HomeSimulatorType.xplane => 'xplane',
      HomeSimulatorType.none => 'xplane',
    };
  }

  int _effectiveIntervalMs(int value) {
    if (!_lowPerformanceMode) {
      return value;
    }
    return value < _lowPerformanceIntervalMs ? _lowPerformanceIntervalMs : value;
  }

  Widget _buildCurrentIntervalLine(
    BuildContext context, {
    required String labelText,
    required int value,
  }) {
    final theme = Theme.of(context);
    final normalStyle = theme.textTheme.bodySmall;
    if (!_lowPerformanceMode) {
      return Text(
        labelText.replaceFirst('{value}', '$value'),
        style: normalStyle,
      );
    }
    final effective = _effectiveIntervalMs(value);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: labelText.replaceFirst('{value}', '$value')),
          TextSpan(
            text: ' -> $effective ms',
            style: normalStyle?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
      style: normalStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHttpForm(context),
        const SizedBox(height: AppThemeData.spacingMedium),
        _buildWsForm(context),
        const SizedBox(height: AppThemeData.spacingMedium),
        _buildRuntimeForm(context),
        const SizedBox(height: AppThemeData.spacingMedium),
        _buildDiagnosisForm(context),
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

  Widget _buildRuntimeForm(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              HttpLocalizationKeys.flightDataSectionTitle.tr(context),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              HttpLocalizationKeys.flightDataSectionDescription.tr(context),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            TextField(
              controller: _flightDataIntervalController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: HttpLocalizationKeys.flightDataIntervalLabel.tr(
                  context,
                ),
                hintText: HttpLocalizationKeys.flightDataIntervalHint.tr(
                  context,
                ),
                prefixIcon: const Icon(Icons.sync_outlined),
              ),
            ),
            const SizedBox(height: AppThemeData.spacingSmall),
            TextField(
              controller: _flightLogIntervalController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: HttpLocalizationKeys.flightLogIntervalLabel.tr(
                  context,
                ),
                hintText: HttpLocalizationKeys.flightLogIntervalHint.tr(
                  context,
                ),
                prefixIcon: const Icon(Icons.timelapse_outlined),
              ),
            ),
            const SizedBox(height: AppThemeData.spacingSmall),
            TextField(
              controller: _uiRefreshIntervalController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: HttpLocalizationKeys.uiRefreshIntervalLabel.tr(
                  context,
                ),
                hintText: HttpLocalizationKeys.uiRefreshIntervalHint.tr(
                  context,
                ),
                prefixIcon: const Icon(Icons.monitor_outlined),
              ),
            ),
            const SizedBox(height: AppThemeData.spacingSmall),
            SwitchListTile(
              value: _lowPerformanceMode,
              contentPadding: EdgeInsets.zero,
              title: Text(
                HttpLocalizationKeys.lowPerformanceModeLabel.tr(context),
              ),
              subtitle: Text(
                HttpLocalizationKeys.lowPerformanceModeHint.tr(context),
                style: theme.textTheme.bodySmall,
              ),
              onChanged: (value) {
                setState(() {
                  _lowPerformanceMode = value;
                });
              },
            ),
            _buildCurrentIntervalLine(
              context,
              labelText: HttpLocalizationKeys.currentFlightDataInterval.tr(
                context,
              ),
              value: _currentFlightDataInterval,
            ),
            const SizedBox(height: 2),
            _buildCurrentIntervalLine(
              context,
              labelText: HttpLocalizationKeys.currentFlightLogInterval.tr(
                context,
              ),
              value: _currentFlightLogInterval,
            ),
            const SizedBox(height: 2),
            _buildCurrentIntervalLine(
              context,
              labelText: HttpLocalizationKeys.currentUiRefreshInterval.tr(
                context,
              ),
              value: _currentUiRefreshInterval,
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSavingSettings
                    ? null
                    : () => _saveRuntimeSettings(context),
                icon: _isSavingSettings
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_as_outlined, size: 18),
                label: Text(
                  _isSavingSettings
                      ? HttpLocalizationKeys.saving.tr(context)
                      : HttpLocalizationKeys.saveButton.tr(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosisForm(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              HttpLocalizationKeys.diagnoseSectionTitle.tr(context),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              HttpLocalizationKeys.diagnoseSectionDescription.tr(context),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppThemeData.spacingMedium),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDiagnosing ? null : () => _runDiagnosis(context),
                icon: _isDiagnosing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.medical_information_outlined, size: 18),
                label: Text(
                  _isDiagnosing
                      ? HttpLocalizationKeys.testing.tr(context)
                      : HttpLocalizationKeys.runDiagnosis.tr(context),
                ),
              ),
            ),
            if (_diagnosisMessages.isNotEmpty) ...[
              const SizedBox(height: AppThemeData.spacingMedium),
              ..._diagnosisMessages.map(
                (message) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(message, style: theme.textTheme.bodySmall),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
