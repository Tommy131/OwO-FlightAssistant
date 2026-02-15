import 'dart:async';
import 'package:flutter/material.dart';
import '../models/home_models.dart';

abstract class HomeDataAdapter {
  Stream<HomeDataSnapshot> get stream;
  Future<bool> connect(HomeSimulatorType type);
  Future<void> disconnect();
  Future<void> setFlightNumber(String? value);
  Future<void> setDestination(HomeAirportInfo? airport);
  Future<void> setAlternate(HomeAirportInfo? airport);
  Future<List<HomeAirportInfo>> searchAirports(String keyword);
  Future<void> refreshMetar(HomeAirportInfo airport);
}

class HomeProvider extends ChangeNotifier {
  HomeProvider({HomeDataAdapter? adapter}) : _adapter = adapter {
    _subscribeAdapter();
  }

  HomeDataAdapter? _adapter;
  StreamSubscription<HomeDataSnapshot>? _subscription;
  HomeDataSnapshot _snapshot = HomeDataSnapshot.empty();

  bool get isConnected => _snapshot.isConnected;
  HomeSimulatorType get simulatorType => _snapshot.simulatorType;
  String? get errorMessage => _snapshot.errorMessage;
  String? get aircraftTitle => _snapshot.aircraftTitle;
  bool? get isPaused => _snapshot.isPaused;
  String? get transponderState => _snapshot.transponderState;
  String? get transponderCode => _snapshot.transponderCode;
  String? get flightNumber => _snapshot.flightNumber;
  bool get hasFlightNumber =>
      _snapshot.flightNumber != null && _snapshot.flightNumber!.isNotEmpty;
  bool? get isFuelSufficient => _snapshot.isFuelSufficient;
  HomeChecklistPhase? get checklistPhase => _snapshot.checklistPhase;
  double get checklistProgress => _snapshot.checklistProgress ?? 0;
  HomeFlightData get flightData => _snapshot.flightData;
  HomeAirportInfo? get destinationAirport => _snapshot.destinationAirport;
  HomeAirportInfo? get alternateAirport => _snapshot.alternateAirport;
  HomeAirportInfo? get nearestAirport => _snapshot.nearestAirport;
  List<HomeAirportInfo> get suggestedAirports => _snapshot.suggestedAirports;
  Map<String, HomeMetarData> get metarsByIcao => _snapshot.metarsByIcao;
  Map<String, String> get metarErrorsByIcao => _snapshot.metarErrorsByIcao;

  void attachAdapter(HomeDataAdapter? adapter) {
    _adapter = adapter;
    _subscribeAdapter();
  }

  Future<bool> connect(HomeSimulatorType type) async {
    final adapter = _adapter;
    if (adapter == null) return false;
    return adapter.connect(type);
  }

  Future<void> disconnect() async {
    final adapter = _adapter;
    if (adapter == null) return;
    await adapter.disconnect();
  }

  Future<void> setFlightNumber(String? value) async {
    final adapter = _adapter;
    if (adapter == null) return;
    await adapter.setFlightNumber(value);
  }

  Future<void> setDestination(HomeAirportInfo? airport) async {
    final adapter = _adapter;
    if (adapter == null) return;
    await adapter.setDestination(airport);
  }

  Future<void> setAlternate(HomeAirportInfo? airport) async {
    final adapter = _adapter;
    if (adapter == null) return;
    await adapter.setAlternate(airport);
  }

  Future<List<HomeAirportInfo>> searchAirports(String keyword) async {
    final adapter = _adapter;
    if (adapter == null) return [];
    return adapter.searchAirports(keyword);
  }

  Future<void> refreshMetar(HomeAirportInfo airport) async {
    final adapter = _adapter;
    if (adapter == null) return;
    await adapter.refreshMetar(airport);
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
}
