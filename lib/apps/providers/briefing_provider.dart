import 'package:flutter/foundation.dart';
import '../models/flight_briefing.dart';
import '../services/briefing_service.dart';
import '../services/briefing_storage_service.dart';
import '../../core/utils/logger.dart';

/// 飞行简报状态管理
class BriefingProvider extends ChangeNotifier {
  final BriefingService _briefingService = BriefingService();
  final BriefingStorageService _storageService = BriefingStorageService();

  FlightBriefing? _currentBriefing;
  bool _isLoading = false;
  String? _errorMessage;

  // 历史简报列表
  final List<FlightBriefing> _briefingHistory = [];
  bool _isHistoryLoaded = false;

  FlightBriefing? get currentBriefing => _currentBriefing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<FlightBriefing> get briefingHistory =>
      List.unmodifiable(_briefingHistory);

  /// 初始化 - 加载历史记录
  Future<void> initialize() async {
    if (_isHistoryLoaded) return;

    try {
      final briefings = await _storageService.loadBriefings();
      _briefingHistory.clear();
      _briefingHistory.addAll(briefings);
      _isHistoryLoaded = true;

      AppLogger.info('简报历史记录已加载: ${briefings.length} 条');
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('加载简报历史失败', e, stackTrace);
    }
  }

  /// 保存历史记录到本地
  Future<void> _saveHistory() async {
    try {
      await _storageService.saveBriefings(_briefingHistory);
    } catch (e, stackTrace) {
      AppLogger.error('保存简报历史失败', e, stackTrace);
    }
  }

  /// 生成新的飞行简报
  Future<bool> generateBriefing({
    required String departureIcao,
    required String arrivalIcao,
    String? alternateIcao,
    String? flightNumber,
    String? route,
    int? cruiseAltitude,
    String? departureRunway,
    String? arrivalRunway,
    // 模拟器重量数据
    int? simulatorTotalWeight,
    int? simulatorEmptyWeight,
    int? simulatorPayloadWeight,
    double? simulatorFuelWeight,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final briefing = await _briefingService.generateBriefing(
        departureIcao: departureIcao,
        arrivalIcao: arrivalIcao,
        alternateIcao: alternateIcao,
        flightNumber: flightNumber,
        route: route,
        cruiseAltitude: cruiseAltitude,
        departureRunway: departureRunway,
        arrivalRunway: arrivalRunway,
        // 传递模拟器重量数据
        simulatorTotalWeight: simulatorTotalWeight,
        simulatorEmptyWeight: simulatorEmptyWeight,
        simulatorPayloadWeight: simulatorPayloadWeight,
        simulatorFuelWeight: simulatorFuelWeight,
      );

      if (briefing != null) {
        _currentBriefing = briefing;
        _briefingHistory.insert(0, briefing);

        // 限制历史记录数量
        if (_briefingHistory.length > 50) {
          _briefingHistory.removeLast();
        }

        // 保存到本地
        await _saveHistory();

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = '生成简报失败，请检查机场代码是否正确';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error in generateBriefing', e, stackTrace);
      _errorMessage = '生成简报时发生错误: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 从历史记录中加载简报
  void loadBriefingFromHistory(int index) {
    if (index >= 0 && index < _briefingHistory.length) {
      _currentBriefing = _briefingHistory[index];
      notifyListeners();
    }
  }

  /// 删除单个简报
  void deleteBriefing(int index) async {
    if (index >= 0 && index < _briefingHistory.length) {
      final deletedBriefing = _briefingHistory[index];
      _briefingHistory.removeAt(index);

      // 如果删除的是当前显示的简报，清除当前简报
      if (_currentBriefing == deletedBriefing) {
        _currentBriefing = null;
      }

      // 保存到本地
      await _saveHistory();

      notifyListeners();
    }
  }

  /// 清除当前简报
  void clearCurrentBriefing() {
    _currentBriefing = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// 清除历史记录
  void clearHistory() async {
    _briefingHistory.clear();

    // 清除本地存储
    await _storageService.clearBriefings();

    notifyListeners();
  }

  /// 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
