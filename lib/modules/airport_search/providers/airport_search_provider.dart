import 'package:flutter/material.dart';
import '../models/airport_search_models.dart';
import '../services/airport_search_service.dart';

/// 机场搜索模块的状态管理类 (Provider)
/// 负责协调 UI 与 Service 之间的数据流，管理查询状态、建议项及收藏状态
class AirportSearchProvider extends ChangeNotifier {
  AirportSearchProvider({AirportSearchService? service})
    : _service = service ?? AirportSearchService();

  /// 核心业务逻辑服务，负责网络请求和持久化存储
  final AirportSearchService _service;

  /// 内部状态标记：是否正在进行初始化（如从磁盘加载收藏列表及其它准备工作）
  bool _isInitializing = false;

  /// 内部状态标记：是否正在执行核心机场查询 (详情 + METAR)
  bool _isSearching = false;

  /// 内部状态标记：是否正在后台异步请求搜索建议列表
  bool _isSuggesting = false;

  /// 存储待在界面显示的错误主键 (Localization Key)
  String? _errorKey;

  /// 存储最近一次成功的全量查询结果
  AirportQueryResult? _latestResult;

  /// 当前所有已收藏的机场项列表
  List<FavoriteAirportEntry> _favorites = [];

  /// 当前输入匹配到的搜索建议列表
  List<AirportSuggestionData> _suggestions = [];

  // --- 公开 Getter 区域 ---
  bool get isInitializing => _isInitializing;
  bool get isSearching => _isSearching;
  bool get isSuggesting => _isSuggesting;
  bool get isBusy => _isInitializing || _isSearching;
  String? get errorKey => _errorKey;
  AirportQueryResult? get latestResult => _latestResult;
  List<FavoriteAirportEntry> get favorites => _favorites;
  List<AirportSuggestionData> get suggestions => _suggestions;

  /// 检查特定的 ICAO 代码是否已存在于本地收藏夹中
  bool isFavorite(String icao) {
    final normalized = _service.normalizeIcao(icao);
    return _favorites.any((item) => item.icao == normalized);
  }

  /// 模块初始化操作：在进入页面时异步从持久化存储加载收藏列表
  Future<void> init() async {
    if (_isInitializing) return;
    _isInitializing = true;
    notifyListeners();
    try {
      _favorites = await _service.loadFavorites();
      _errorKey = null;
    } catch (_) {
      _errorKey = 'favoriteLoadFailed';
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// 发起完整的机场信息查询 (详情、跑道、频率、METAR 气象等)
  Future<void> queryAirport(String input) async {
    final normalized = _service.normalizeIcao(input);
    // 校验输入格式: 为严谨起见，全量查询必须符合标准 4 位 ICAO
    if (!_service.isValidIcao(normalized)) {
      _errorKey = 'invalidIcao';
      notifyListeners();
      return;
    }

    _isSearching = true;
    _suggestions = []; // 清空建议列表以突出显示当前查询结果
    _errorKey = null;
    notifyListeners();

    try {
      _latestResult = await _service.queryAirportAndMetar(normalized);
    } catch (_) {
      _errorKey = 'queryFailed';
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// 根据当前输入动态更新搜索建议列表
  /// 配合 UI 层的防抖处理使用，优化 API 请求频率
  Future<void> updateSuggestions(String input) async {
    final normalized = _service.normalizeIcao(input);
    // 输入为空或非有效 ICAO 字冠时，立即清空建议列表
    if (normalized.isEmpty || !_service.isValidIcaoPartial(normalized)) {
      _suggestions = [];
      _isSuggesting = false;
      notifyListeners();
      return;
    }

    _isSuggesting = true;
    notifyListeners();
    try {
      _suggestions = await _service.suggestAirports(normalized);
    } catch (_) {
      _suggestions = [];
    } finally {
      _isSuggesting = false;
      notifyListeners();
    }
  }

  /// 选中某个建议项后的快速联动查询
  Future<void> querySuggestion(AirportSuggestionData suggestion) async {
    await queryAirport(suggestion.icao);
  }

  /// 针对当前查询出的机场详情切换收藏状态 (Toggle)
  /// 操作结果会自动同步持久化到本地文件
  Future<void> toggleFavoriteForLatest() async {
    final result = _latestResult;
    if (result == null) return;
    final icao = result.airport.icao;
    final index = _favorites.indexWhere((item) => item.icao == icao);

    // 逻辑：已有的移除，没有的则添加至首位
    if (index >= 0) {
      _favorites.removeAt(index);
      try {
        await _service.saveFavorites(_favorites);
        _errorKey = null;
      } catch (_) {
        _errorKey = 'favoriteSaveFailed';
      }
      notifyListeners();
      return;
    }

    final entry = FavoriteAirportEntry(
      icao: icao,
      name: result.airport.name,
      latitude: result.airport.latitude,
      longitude: result.airport.longitude,
    );
    _favorites = [entry, ..._favorites];
    try {
      await _service.saveFavorites(_favorites);
      _errorKey = null;
    } catch (_) {
      _errorKey = 'favoriteSaveFailed';
    }
    notifyListeners();
  }

  /// 从收藏便捷列表中点击某项进行查询
  Future<void> selectFavoriteAndQuery(String icao) async {
    await queryAirport(icao);
  }

  /// 清除当前正在显示的错误状态，用于重置页面的错误提示 UI
  void clearError() {
    if (_errorKey == null) return;
    _errorKey = null;
    notifyListeners();
  }
}
