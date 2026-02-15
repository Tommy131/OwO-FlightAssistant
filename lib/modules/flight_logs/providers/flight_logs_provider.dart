import 'package:flutter/material.dart';
import '../models/flight_log_models.dart';

abstract class FlightLogsAdapter {
  Future<List<FlightLog>> loadLogs();
  Future<void> deleteLog(String id);
  Future<void> exportLog(FlightLog log);
  Future<void> importLog();
}

class FlightLogsProvider extends ChangeNotifier {
  FlightLogsProvider({FlightLogsAdapter? adapter}) : _adapter = adapter;

  FlightLogsAdapter? _adapter;
  List<FlightLog> _logs = [];
  bool _isLoading = false;
  FlightLog? _selectedLog;

  List<FlightLog> get logs => _logs;
  bool get isLoading => _isLoading;
  FlightLog? get selectedLog => _selectedLog;

  void attachAdapter(FlightLogsAdapter? adapter) {
    _adapter = adapter;
    notifyListeners();
  }

  Future<void> refreshLogs() async {
    if (_adapter == null) return;
    _isLoading = true;
    notifyListeners();
    _logs = await _adapter!.loadLogs();
    _isLoading = false;
    if (_selectedLog != null &&
        !_logs.any((log) => log.id == _selectedLog!.id)) {
      _selectedLog = null;
    }
    notifyListeners();
  }

  void selectLog(FlightLog log) {
    _selectedLog = log;
    notifyListeners();
  }

  void clearSelection() {
    _selectedLog = null;
    notifyListeners();
  }

  Future<bool> deleteLog(String id) async {
    if (_adapter == null) return false;
    await _adapter!.deleteLog(id);
    await refreshLogs();
    return true;
  }

  Future<bool> exportLog(FlightLog log) async {
    if (_adapter == null) return false;
    await _adapter!.exportLog(log);
    return true;
  }

  Future<bool> importLog() async {
    if (_adapter == null) return false;
    await _adapter!.importLog();
    await refreshLogs();
    return true;
  }
}
