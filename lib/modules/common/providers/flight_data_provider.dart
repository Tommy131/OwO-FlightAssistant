import 'dart:async';

import 'package:flutter/material.dart';

import '../models/common_models.dart';
import 'flight_data_adapter.dart';
import 'middleware_flight_data_adapter.dart';

/// 飞行数据 Provider
///
/// 负责持有 [FlightDataAdapter] 并将其产生的 [FlightDataSnapshot] 暴露给 UI 层。
/// 本身不包含任何业务逻辑，仅做状态代理与 ChangeNotifier 通知。
///
/// 使用者通过 [Provider.of] / [context.watch] 订阅:
/// ```dart
/// context.watch<FlightDataProvider>().flightData
/// ```
class FlightDataProvider extends ChangeNotifier {
  FlightDataProvider({FlightDataAdapter? adapter}) : _adapter = adapter {
    _subscribeAdapter();
    unawaited(refreshBackendHealth());
  }

  FlightDataAdapter? _adapter;
  StreamSubscription<FlightDataSnapshot>? _subscription;
  FlightDataSnapshot _snapshot = FlightDataSnapshot.empty();

  // ──────────────────────────────────────────────────────────────────────────
  // 快照属性代理
  // ──────────────────────────────────────────────────────────────────────────

  bool get isConnected => _snapshot.isConnected;
  bool get isBackendReachable => _snapshot.isBackendReachable;
  int get backendOutageVersion => _snapshot.backendOutageVersion;
  FlightDataSnapshot get snapshot => _snapshot;
  SimulatorType get simulatorType => _snapshot.simulatorType;
  String? get errorMessage => _snapshot.errorMessage;
  String? get aircraftTitle => _snapshot.aircraftTitle;
  bool? get isPaused => _snapshot.isPaused;
  String? get transponderState => _snapshot.transponderState;
  String? get transponderCode => _snapshot.transponderCode;
  String? get flightNumber => _snapshot.flightNumber;
  bool get hasFlightNumber =>
      _snapshot.flightNumber != null && _snapshot.flightNumber!.isNotEmpty;
  bool? get isFuelSufficient => _snapshot.isFuelSufficient;
  FlightChecklistPhase? get checklistPhase => _snapshot.checklistPhase;
  double get checklistProgress => _snapshot.checklistProgress ?? 0;
  FlightData get flightData => _snapshot.flightData;
  AirportInfo? get departureAirport => _snapshot.departureAirport;
  AirportInfo? get destinationAirport => _snapshot.destinationAirport;
  AirportInfo? get alternateAirport => _snapshot.alternateAirport;
  AirportInfo? get nearestAirport => _snapshot.nearestAirport;
  List<AirportInfo> get suggestedAirports => _snapshot.suggestedAirports;
  Map<String, LiveMetarData> get metarsByIcao => _snapshot.metarsByIcao;
  Map<String, String> get metarErrorsByIcao => _snapshot.metarErrorsByIcao;
  Set<String> get metarRefreshingIcaos => _snapshot.metarRefreshingIcaos;

  // ──────────────────────────────────────────────────────────────────────────
  // 适配器绑定
  // ──────────────────────────────────────────────────────────────────────────

  /// 替换当前适配器并重新订阅
  void attachAdapter(FlightDataAdapter? adapter) {
    _adapter = adapter;
    _subscribeAdapter();
    unawaited(refreshBackendHealth());
  }

  void _subscribeAdapter() {
    _subscription?.cancel();
    final adapter = _adapter;
    if (adapter == null) return;
    _subscription = adapter.stream.listen((snapshot) {
      _snapshot = snapshot;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 代理操作（委托给 adapter）
  // ──────────────────────────────────────────────────────────────────────────

  Future<bool> connect(SimulatorType type) async {
    return await _adapter?.connect(type) ?? false;
  }

  Future<void> disconnect() async => _adapter?.disconnect();

  Future<bool> refreshBackendHealth() async {
    return await _adapter?.refreshBackendHealth() ?? false;
  }

  Future<int> getFlightDataIntervalMs() async {
    return await _adapter?.getFlightDataIntervalMs() ??
        MiddlewareFlightDataAdapter.defaultPollIntervalMs;
  }

  Future<void> setFlightDataIntervalMs(int milliseconds) async {
    await _adapter?.setFlightDataIntervalMs(milliseconds);
  }

  Future<void> setFlightNumber(String? value) async {
    await _adapter?.setFlightNumber(value);
  }

  Future<void> setDeparture(AirportInfo? airport) async {
    await _adapter?.setDeparture(airport);
  }

  Future<void> setDestination(AirportInfo? airport) async {
    await _adapter?.setDestination(airport);
  }

  Future<void> setAlternate(AirportInfo? airport) async {
    await _adapter?.setAlternate(airport);
  }

  Future<List<AirportInfo>> searchAirports(String keyword) async {
    return await _adapter?.searchAirports(keyword) ?? [];
  }

  Future<void> refreshMetar(AirportInfo airport) async {
    await _adapter?.refreshMetar(airport);
  }
}
