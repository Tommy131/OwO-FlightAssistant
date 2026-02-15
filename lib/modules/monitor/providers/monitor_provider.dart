import 'dart:async';
import 'package:flutter/material.dart';
import '../models/monitor_models.dart';

abstract class MonitorDataAdapter {
  Stream<MonitorData> get stream;
}

class MonitorProvider extends ChangeNotifier {
  MonitorProvider({MonitorDataAdapter? adapter}) : _adapter = adapter {
    _subscribeAdapter();
  }

  MonitorDataAdapter? _adapter;
  StreamSubscription<MonitorData>? _subscription;
  MonitorData _data = MonitorData.empty();

  MonitorData get data => _data;
  bool get isConnected => _data.isConnected;
  MonitorChartData get chartData => _data.chartData;

  void attachAdapter(MonitorDataAdapter? adapter) {
    _adapter = adapter;
    _subscribeAdapter();
  }

  void updateData(MonitorData data) {
    _data = data;
    notifyListeners();
  }

  void _subscribeAdapter() {
    _subscription?.cancel();
    final adapter = _adapter;
    if (adapter == null) return;
    _subscription = adapter.stream.listen((data) {
      _data = data;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
