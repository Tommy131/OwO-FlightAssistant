import 'package:flutter/material.dart';

/// 全局航班信息提供者
class FlightProvider extends ChangeNotifier {
  String? _flightNumber;

  String? get flightNumber => _flightNumber;
  bool get hasFlightNumber =>
      _flightNumber != null && _flightNumber!.isNotEmpty;

  /// 更新航班号
  void setFlightNumber(String? value) {
    if (_flightNumber == value) return;
    _flightNumber = value;
    notifyListeners();
  }

  /// 清除航班号
  void clearFlightNumber() {
    if (_flightNumber == null) return;
    _flightNumber = null;
    notifyListeners();
  }
}
