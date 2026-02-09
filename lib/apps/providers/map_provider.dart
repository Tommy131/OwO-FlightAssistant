import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/airport_detail_data.dart';
import '../services/airport_detail_service.dart';
import 'simulator/simulator_provider.dart';

class MapProvider with ChangeNotifier {
  final SimulatorProvider _simulatorProvider;
  final AirportDetailService _airportService = AirportDetailService();

  AirportDetailData? _currentAirport;
  final List<LatLng> _path = [];
  bool _isLoadingAirport = false;
  String? _lastIcao;

  MapProvider(this._simulatorProvider) {
    _simulatorProvider.addListener(_onSimulatorUpdate);
  }

  AirportDetailData? get currentAirport => _currentAirport;
  List<LatLng> get path => _path;
  bool get isLoadingAirport => _isLoadingAirport;

  void _onSimulatorUpdate() {
    final data = _simulatorProvider.simulatorData;
    if (data.latitude != null && data.longitude != null) {
      final pos = LatLng(data.latitude!, data.longitude!);

      // Update path
      if (_path.isEmpty || _path.last != pos) {
        _path.add(pos);
        if (_path.length > 1000) _path.removeAt(0);
        notifyListeners();
      }

      // Check for nearest airport change
      final nearest = _simulatorProvider.nearestAirport;
      if (nearest != null && nearest.icaoCode != _lastIcao) {
        _lastIcao = nearest.icaoCode;
        _loadAirportDetail(nearest.icaoCode);
      }
    }
  }

  Future<void> _loadAirportDetail(String icao) async {
    _isLoadingAirport = true;
    notifyListeners();

    try {
      // Try local/X-Plane data first as it has better geometry
      final detail = await _airportService.fetchAirportDetail(
        icao,
        preferredSource: AirportDataSource.xplaneData,
      );
      _currentAirport = detail;
    } catch (e) {
      _currentAirport = null;
    } finally {
      _isLoadingAirport = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _simulatorProvider.removeListener(_onSimulatorUpdate);
    super.dispose();
  }
}
