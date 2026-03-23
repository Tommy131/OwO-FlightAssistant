import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/persistence_service.dart';
import '../../common/models/common_models.dart';
import '../models/monitor_chart_data.dart';
import '../models/monitor_data.dart';
import 'monitor_chart_buffer.dart';

/// 外部数据源适配器接口
///
/// 允许不同数据来源（如 WebSocket、模拟器 SDK）通过统一接口
/// 将 [MonitorData] 流推送给 [MonitorProvider]。
abstract class MonitorDataAdapter {
  /// 监控数据流，每帧推送一次最新飞行状态
  Stream<MonitorData> get stream;
}

/// 监控模块状态管理 Provider
///
/// 负责以下职责：
/// 1. 监听来自 [HomeProvider] 快照或外部 [MonitorDataAdapter] 的飞行数据；
/// 2. 委托 [MonitorChartBuffer] 维护图表历史数据缓冲区；
/// 3. 读取性能设置（低性能模式 / UI 刷新间隔），限制通知频率以降低 GPU 压力；
/// 4. 暴露当前 [MonitorData] 给 UI 层使用。
class MonitorProvider extends ChangeNotifier {
  MonitorProvider({MonitorDataAdapter? adapter}) : _adapter = adapter {
    _subscribeAdapter();
    unawaited(_loadPerformanceSettings());
  }

  // ── 性能设置相关常量 ──────────────────────────────────────────────────────
  /// 读取性能设置时使用的模块名称（对应持久化存储中的 namespace）
  static const String _settingsModuleName = 'performance';

  /// 低性能模式开关的持久化键名
  static const String _lowPerformanceModeKey = 'low_performance_mode';

  /// UI 刷新间隔（毫秒）的持久化键名
  static const String _uiRefreshIntervalMsKey = 'ui_refresh_interval_ms';

  /// 默认 UI 刷新间隔（毫秒）
  static const int _defaultUiRefreshIntervalMs = 120;

  /// 低性能模式下强制使用的最低刷新间隔（毫秒）
  static const int _lowPerformanceRefreshIntervalMs = 500;

  // ── 内部状态 ──────────────────────────────────────────────────────────────

  /// 当前外部数据适配器（可为 null，表示仅依赖 HomeProvider 快照）
  MonitorDataAdapter? _adapter;

  /// 外部适配器 Stream 的订阅句柄
  StreamSubscription<MonitorData>? _subscription;

  /// 当前飞行数据快照
  MonitorData _data = MonitorData.empty();

  /// 图表时序数据缓冲管理器
  final MonitorChartBuffer _chartBuffer = MonitorChartBuffer();

  /// 是否处于低性能模式
  bool _lowPerformanceMode = false;

  /// 当前配置的 UI 刷新间隔（毫秒）
  int _uiRefreshIntervalMs = _defaultUiRefreshIntervalMs;

  /// 上次触发 notifyListeners 的时间戳（用于限流）
  DateTime? _lastUiNotifyAt;

  // ── 对外暴露的只读属性 ────────────────────────────────────────────────────

  /// 当前完整的飞行数据快照
  MonitorData get data => _data;

  /// 模拟器是否已连接
  bool get isConnected => _data.isConnected;

  /// 当前图表历史数据（由 [MonitorChartBuffer] 维护）
  MonitorChartData get chartData => _data.chartData;

  // ── 公开方法 ──────────────────────────────────────────────────────────────

  /// 挂载或替换外部数据适配器
  void attachAdapter(MonitorDataAdapter? adapter) {
    _adapter = adapter;
    _subscribeAdapter();
  }

  /// 直接设置一帧监控数据（供测试或内部调用）
  void updateData(MonitorData data) {
    _data = data;
    if (_shouldNotifyUi()) {
      notifyListeners();
    }
  }

  /// 从 [HomeDataSnapshot] 更新监控数据
  ///
  /// 每次 [HomeProvider] 数据变化时由 [ChangeNotifierProxyProvider] 调用。
  /// 若模拟器未暂停，则向图表缓冲区追加当前帧数据。
  void updateFromHomeSnapshot(HomeDataSnapshot snapshot) {
    final flightData = snapshot.flightData;
    final isPaused = snapshot.isPaused == true;

    // 仅在非暂停状态下向图表缓冲区追加数据点
    if (!isPaused) {
      _chartBuffer.append(
        gForce: flightData.gForce ?? 1.0,
        altitude: flightData.altitude ?? 0,
        pressure: flightData.baroPressure ?? 29.92,
      );
    }

    // 构造最新数据快照（含图表缓冲区当前帧）
    _data = MonitorData(
      isConnected: snapshot.isConnected,
      chartData: _chartBuffer.buildSnapshot(),
      isPaused: snapshot.isPaused,
      masterWarning: flightData.masterWarning,
      masterCaution: flightData.masterCaution,
      heading: flightData.heading,
      parkingBrake: flightData.parkingBrake,
      transponderState: snapshot.transponderState,
      transponderCode: snapshot.transponderCode,
      flapsLabel: flightData.flapsLabel,
      flapsDeployRatio: flightData.flapsDeployRatio,
      speedBrakeLabel: flightData.speedBrakeLabel,
      speedBrake: flightData.speedBrake,
      fireWarningEngine1: flightData.fireWarningEngine1,
      fireWarningEngine2: flightData.fireWarningEngine2,
      fireWarningAPU: flightData.fireWarningAPU,
      noseGearDown: flightData.noseGearDown,
      leftGearDown: flightData.leftGearDown,
      rightGearDown: flightData.rightGearDown,
      gForce: flightData.gForce,
      altitude: flightData.altitude,
      baroPressure: flightData.baroPressure,
    );

    if (_shouldNotifyUi()) {
      notifyListeners();
    }
  }

  /// 重新加载性能设置并刷新 UI
  Future<void> refreshPerformanceSettings() async {
    await _loadPerformanceSettings();
    notifyListeners();
  }

  // ── 内部私有方法 ──────────────────────────────────────────────────────────

  /// 订阅外部数据适配器的 Stream，取消旧的订阅后重新建立
  void _subscribeAdapter() {
    _subscription?.cancel();
    final adapter = _adapter;
    if (adapter == null) return;
    _subscription = adapter.stream.listen((data) {
      _data = data;
      if (_shouldNotifyUi()) {
        notifyListeners();
      }
    });
  }

  /// 判断当前是否应触发 UI 刷新（基于刷新间隔限流）
  ///
  /// 低性能模式下，使用配置间隔与 [_lowPerformanceRefreshIntervalMs] 中较大值。
  bool _shouldNotifyUi() {
    final now = DateTime.now();
    final minInterval = _lowPerformanceMode
        ? (_uiRefreshIntervalMs > _lowPerformanceRefreshIntervalMs
              ? _uiRefreshIntervalMs
              : _lowPerformanceRefreshIntervalMs)
        : _uiRefreshIntervalMs;
    if (_lastUiNotifyAt == null ||
        now.difference(_lastUiNotifyAt!).inMilliseconds >= minInterval) {
      _lastUiNotifyAt = now;
      return true;
    }
    return false;
  }

  /// 从持久化存储中读取性能相关设置
  Future<void> _loadPerformanceSettings() async {
    final persistence = PersistenceService();
    await persistence.ensureReady();

    // 读取低性能模式开关
    _lowPerformanceMode =
        persistence.getModuleData<bool>(
          _settingsModuleName,
          _lowPerformanceModeKey,
        ) ??
        false;

    // 读取 UI 刷新间隔并约束在合法范围内（60ms ~ 2000ms）
    final storedInterval =
        persistence.getModuleData<int>(
          _settingsModuleName,
          _uiRefreshIntervalMsKey,
        ) ??
        _defaultUiRefreshIntervalMs;
    _uiRefreshIntervalMs = storedInterval.clamp(60, 2000).toInt();
  }

  @override
  void dispose() {
    // 销毁时取消 Stream 订阅，防止内存泄漏
    _subscription?.cancel();
    super.dispose();
  }
}
