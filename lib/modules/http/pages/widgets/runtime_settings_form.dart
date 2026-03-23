import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/localization_service.dart';
import '../../../../core/services/persistence_service.dart';
import '../../../../core/theme/app_theme_data.dart';
import '../../../../core/widgets/common/snack_bar.dart';
import '../../../flight_logs/providers/flight_logs_provider.dart';
import '../../../map/providers/map_provider.dart';
import '../../../monitor/providers/monitor_provider.dart';
import '../../../common/providers/common_provider.dart';
import '../../localization/http_localization_keys.dart';

/// 运行时性能参数配置表单卡片
///
/// 负责管理以下运行时可调参数：
/// - 飞行数据采集间隔（flight_data_interval_ms）
/// - 飞行日志采样间隔（flight_log_interval_ms）
/// - UI 刷新间隔（ui_refresh_interval_ms）
/// - 低性能模式开关（low_performance_mode）
class RuntimeSettingsForm extends StatefulWidget {
  const RuntimeSettingsForm({super.key});

  @override
  State<RuntimeSettingsForm> createState() => _RuntimeSettingsFormState();
}

class _RuntimeSettingsFormState extends State<RuntimeSettingsForm> {
  final TextEditingController _flightDataIntervalController =
      TextEditingController();
  final TextEditingController _flightLogIntervalController =
      TextEditingController();
  final TextEditingController _uiRefreshIntervalController =
      TextEditingController();

  bool _isSaving = false;
  bool _lowPerformanceMode = false;

  /// 当前已生效的飞行数据采集间隔（ms）
  int _currentFlightDataInterval = 300;

  /// 当前已生效的飞行日志采样间隔（ms）
  int _currentFlightLogInterval = FlightLogsProvider.defaultSampleIntervalMs;

  /// 当前已生效的 UI 刷新间隔（ms）
  int _currentUiRefreshInterval = 120;

  // 存储模块名及键名常量
  static const String _performanceModuleName = 'performance';
  static const String _lowPerformanceModeKey = 'low_performance_mode';
  static const String _uiRefreshIntervalMsKey = 'ui_refresh_interval_ms';

  /// 低性能模式下的最低间隔限制（ms）
  static const int _lowPerformanceIntervalMs = 500;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSettings();
    });
  }

  @override
  void dispose() {
    _flightDataIntervalController.dispose();
    _flightLogIntervalController.dispose();
    _uiRefreshIntervalController.dispose();
    super.dispose();
  }

  /// 从持久化存储和 Provider 加载当前配置值
  Future<void> _loadSettings() async {
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

  /// 保存运行时设置并同步到相关 Provider
  Future<void> _save(BuildContext context) async {
    final flightDataInterval = int.tryParse(
      _flightDataIntervalController.text.trim(),
    );
    final flightLogInterval = int.tryParse(
      _flightLogIntervalController.text.trim(),
    );
    final uiRefreshInterval = int.tryParse(
      _uiRefreshIntervalController.text.trim(),
    );

    // 合法性校验
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

    setState(() => _isSaving = true);
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 计算低性能模式下实际生效的间隔值
  int _effectiveIntervalMs(int value) {
    if (!_lowPerformanceMode) return value;
    return value < _lowPerformanceIntervalMs
        ? _lowPerformanceIntervalMs
        : value;
  }

  /// 构建当前间隔展示行
  ///
  /// 低性能模式启用时在原始值后附加实际生效值（红色加粗）
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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 区块标题 + 描述
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

            // 飞行数据采集间隔
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

            // 飞行日志采样间隔
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

            // UI 刷新间隔
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

            // 低性能模式开关
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
              onChanged: (value) => setState(() => _lowPerformanceMode = value),
            ),

            // 当前生效值展示
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

            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _save(context),
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_as_outlined, size: 18),
                label: Text(
                  _isSaving
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
}
