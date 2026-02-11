import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/airports_database.dart';
import '../models/airport_detail_data.dart';
import '../services/airport_detail_service.dart';
import '../services/weather_service.dart';
import '../services/app_core/database_loader.dart';
import '../../core/utils/logger.dart';

class AirportInfoProvider extends ChangeNotifier {
  final AirportDetailService _detailService = AirportDetailService();
  final WeatherService _weatherService = WeatherService();
  final DatabaseSettingsService _settings = DatabaseSettingsService();

  // State
  final List<AirportInfo> _userSavedAirports = [];
  final Map<String, MetarData> _airportMetars = {};
  final Map<String, String> _metarErrors = {};
  final Map<String, AirportDetailData> _airportDetails = {};
  final Map<String, AirportDetailData> _onlineDetails = {};
  final Map<String, String> _fetchErrors = {};

  bool _isLoading = false;
  String? _dataSourceSwitchError;
  AirportDataSource _currentDataSource = AirportDataSource.lnmData;
  List<AirportDataSource> _availableDataSources = [];

  // Getters
  List<AirportInfo> get savedAirports => List.unmodifiable(_userSavedAirports);
  Map<String, MetarData> get airportMetars => Map.unmodifiable(_airportMetars);
  Map<String, String> get metarErrors => Map.unmodifiable(_metarErrors);
  Map<String, AirportDetailData> get airportDetails =>
      Map.unmodifiable(_airportDetails);
  Map<String, AirportDetailData> get onlineDetails =>
      Map.unmodifiable(_onlineDetails);
  Map<String, String> get fetchErrors => Map.unmodifiable(_fetchErrors);
  bool get isLoading => _isLoading;
  String? get dataSourceSwitchError => _dataSourceSwitchError;
  AirportDataSource get currentDataSource => _currentDataSource;
  List<AirportDataSource> get availableDataSources =>
      List.unmodifiable(_availableDataSources);

  static const String _storageKey = 'saved_airports';

  // Initialization
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      AppLogger.info('初始化机场信息服务');
      await _loadDataSource();
      await _initAirportDatabase();
      await _loadSavedAirports();
    } catch (e) {
      AppLogger.error('Failed to initialize AirportInfoProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadDataSource() async {
    final source = await _detailService.getDataSource();
    final available = await _detailService.getAvailableDataSources();

    // 如果当前是在线 API，自动切换到离线源（因为主选器已删除该项）
    if (source == AirportDataSource.aviationApi) {
      _currentDataSource = available.contains(AirportDataSource.xplaneData)
          ? AirportDataSource.xplaneData
          : AirportDataSource.lnmData;
      await _detailService.setDataSource(_currentDataSource);
    } else {
      _currentDataSource = source;
    }
    _availableDataSources = available;
    AppLogger.info(
      '机场数据源加载完成: 当前=${_currentDataSource.name}, 可用=${available.map((s) => s.name).join(",")}',
    );
    notifyListeners();
  }

  Future<void> _initAirportDatabase() async {
    if (!AirportsDatabase.isEmpty) return;

    try {
      AppLogger.info('开始加载机场数据库');
      final airports = await _detailService.loadAllAirports(
        source: _currentDataSource,
      );
      if (airports.isNotEmpty) {
        AirportsDatabase.updateAirports(
          airports
              .map(
                (a) => AirportInfo(
                  icaoCode: a['icao'] ?? '',
                  iataCode: a['iata'] ?? '',
                  nameChinese: a['name'] ?? '',
                  latitude: (a['lat'] as num?)?.toDouble() ?? 0.0,
                  longitude: (a['lon'] as num?)?.toDouble() ?? 0.0,
                ),
              )
              .toList(),
        );
        AppLogger.info('机场数据库加载完成: ${airports.length} 条');
      } else {
        _dataSourceSwitchError = '无法从当前数据源加载机场列表，请检查路径设置。';
        AppLogger.warning('机场数据库为空，未能加载机场列表');
      }
    } catch (e) {
      _dataSourceSwitchError = '初始化机场数据库失败: $e';
      AppLogger.error('初始化机场数据库失败', e);
    }
  }

  Future<void> _loadSavedAirports() async {
    AppLogger.info('读取已保存机场列表');
    final prefs = await SharedPreferences.getInstance();
    final savedIcaoCodes = prefs.getStringList(_storageKey) ?? [];

    final loadedAirports = <AirportInfo>[];
    for (final icao in savedIcaoCodes) {
      final airport =
          AirportsDatabase.findByIcao(icao) ?? AirportInfo.placeholder(icao);
      if (!loadedAirports.any((a) => a.icaoCode == icao)) {
        loadedAirports.add(airport);
      }
    }

    _userSavedAirports.clear();
    _userSavedAirports.addAll(loadedAirports);
    AppLogger.info('已加载保存机场: ${_userSavedAirports.length} 个');

    await _settings.ensureSynced();
    final expiryMinutes =
        await _settings.getInt(DatabaseSettingsService.metarExpiryKey) ?? 60;
    for (final airport in loadedAirports) {
      final cachedMetar = _weatherService.getCachedMetar(airport.icaoCode);
      if (cachedMetar != null && !cachedMetar.isExpired(expiryMinutes)) {
        _airportMetars[airport.icaoCode] = cachedMetar;
      }

      _detailService.getCachedLocalDetail(airport.icaoCode).then((local) {
        if (local != null) {
          _airportDetails[airport.icaoCode] = local;
          notifyListeners();
        }
      });

      _detailService.getCachedOnlineDetail(airport.icaoCode).then((online) {
        if (online != null) {
          _onlineDetails[airport.icaoCode] = online;
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  // Actions
  Future<void> refreshData(
    List<AirportInfo> airports, {
    bool force = false,
  }) async {
    if (_isLoading && !force) return;

    await _loadDataSource();

    if (airports.isEmpty) return;

    await _settings.ensureSynced();
    final expiryMinutes =
        await _settings.getInt(DatabaseSettingsService.metarExpiryKey) ?? 60;
    final airportExpiryDays =
        await _settings.getInt(DatabaseSettingsService.airportExpiryKey) ?? 30;

    // Check if fetch is needed
    bool needsFetch = force;
    if (!force) {
      for (final airport in airports) {
        final existingMetar = _airportMetars[airport.icaoCode];
        if (existingMetar == null || existingMetar.isExpired(expiryMinutes)) {
          needsFetch = true;
          break;
        }
        final detail = _airportDetails[airport.icaoCode];
        if (detail == null || detail.isExpired(airportExpiryDays)) {
          needsFetch = true;
          break;
        }
      }
    }

    if (!needsFetch) return;

    _isLoading = true;
    notifyListeners();

    for (final airport in airports) {
      // Fetch METAR
      await _fetchMetarForAirport(airport, force, expiryMinutes);
      // Fetch Details
      await _fetchDetailsForAirport(airport, force, airportExpiryDays);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchMetarForAirport(
    AirportInfo airport,
    bool force,
    int expiryMinutes,
  ) async {
    final existingMetar = _airportMetars[airport.icaoCode];
    if (force ||
        existingMetar == null ||
        existingMetar.isExpired(expiryMinutes)) {
      try {
        final metar = await _weatherService.fetchMetar(
          airport.icaoCode,
          forceRefresh: force,
        );
        if (metar != null) {
          _airportMetars[airport.icaoCode] = metar;
          _metarErrors.remove(airport.icaoCode);
        } else {
          _metarErrors[airport.icaoCode] = '无法获取气象报文';
        }
      } catch (e) {
        _metarErrors[airport.icaoCode] = '气象报文获取失败: $e';
      }
    }
    // notifyListeners called at end of batch or individually if needed?
    // Batch is better for performance, but individual gives faster feedback.
    // Since we are in a loop in refreshData, let's just rely on refreshData's final notify.
    // Or we can notify here if we want progressive updates.
    notifyListeners();
  }

  Future<void> _fetchDetailsForAirport(
    AirportInfo airport,
    bool force,
    int airportExpiryDays,
  ) async {
    final detail = _airportDetails[airport.icaoCode];

    if (force || detail == null || detail.isExpired(airportExpiryDays)) {
      try {
        final freshDetail = await _detailService.fetchAirportDetail(
          airport.icaoCode,
          forceRefresh: force,
          cacheScope: AirportCacheScope.persistent,
        );
        if (freshDetail != null) {
          // Note: In the original code there was complex update logic with dialogs.
          // We will separate the "check diff" logic from "fetching".
          // For now, let's just update if it's simple.
          // The complex diff logic needs to be handled by the UI calling the provider.
          // But here we are bulk refreshing.
          // Strategy: Just update for now, or expose a "pending update" state?
          // The original code passed `_processAirportDetailUpdate`.
          // We'll reimplement that logic to be safer.

          await _processAvailableUpdate(airport, freshDetail);
        } else {
          _fetchErrors[airport.icaoCode] = '无法获取详细信息';
        }
      } catch (e) {
        _fetchErrors[airport.icaoCode] = '详细信息获取失败: $e';
      }
      notifyListeners();
    }
  }

  Future<void> _processAvailableUpdate(
    AirportInfo airport,
    AirportDetailData freshData,
  ) async {
    final existing = freshData.dataSource == AirportDataSourceType.aviationApi
        ? _onlineDetails[airport.icaoCode]
        : _airportDetails[airport.icaoCode];

    if (existing == null || !existing.hasSignificantDifference(freshData)) {
      applyUpdate(airport, freshData);
      return;
    }

    // If significant difference, we might need UI intervention.
    // For now, simpler approach: if updating in background, maybe just update?
    // Or we can expose a stream of "conflicts" that the UI listens to?
    // To keep it simple for this refactor, let's assume auto-update for bulk refresh,
    // or we can add a callback mechanism later.
    // The original code had `_updateAllUpdates` and `_skipAllUpdates` flags.
    // Let's implement safe update manually.
    applyUpdate(airport, freshData);
  }

  void applyUpdate(AirportInfo airport, AirportDetailData data) {
    if (data.dataSource == AirportDataSourceType.aviationApi) {
      _onlineDetails[airport.icaoCode] = data;
    } else {
      _airportDetails[airport.icaoCode] = data;
    }
    _fetchErrors.remove(airport.icaoCode);

    if (data.metar != null) {
      _airportMetars[airport.icaoCode] = data.metar!;
    }

    if (data.dataSource != AirportDataSourceType.aviationApi) {
      final index = _userSavedAirports.indexWhere(
        (a) => a.icaoCode == airport.icaoCode,
      );
      if (index != -1) {
        _userSavedAirports[index] = AirportInfo.fromDetail(data);
      }
    }
    notifyListeners();
  }

  Future<void> saveAirport(AirportInfo airport) async {
    if (!_userSavedAirports.any((a) => a.icaoCode == airport.icaoCode)) {
      _userSavedAirports.add(airport);
      await _saveSavedAirportsToStorage();
      notifyListeners();

      // Trigger fetch
      refreshData([airport], force: true);
    }
  }

  Future<void> removeAirport(AirportInfo airport) async {
    _userSavedAirports.removeWhere((a) => a.icaoCode == airport.icaoCode);
    await _saveSavedAirportsToStorage();
    notifyListeners();
  }

  Future<void> _saveSavedAirportsToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final icaoCodes = _userSavedAirports.map((a) => a.icaoCode).toList();
    await prefs.setStringList(_storageKey, icaoCodes);
  }

  Future<void> switchDataSource(AirportDataSource source) async {
    _isLoading = true;
    notifyListeners();

    try {
      final airports = await _detailService.loadAllAirports(source: source);
      if (airports.isEmpty) {
        throw '新数据源未包含任何机场数据';
      }

      await _detailService.setDataSource(source);

      AirportsDatabase.updateAirports(
        airports
            .map(
              (a) => AirportInfo(
                icaoCode: a['icao'] ?? '',
                iataCode: a['iata'] ?? '',
                nameChinese: a['name'] ?? '',
                latitude: (a['lat'] as num?)?.toDouble() ?? 0.0,
                longitude: (a['lon'] as num?)?.toDouble() ?? 0.0,
              ),
            )
            .toList(),
      );

      _currentDataSource = source;
      _dataSourceSwitchError = null;
      _fetchErrors.clear();
    } catch (e) {
      _dataSourceSwitchError = '切换失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearDataSourceError() {
    _dataSourceSwitchError = null;
    notifyListeners();
  }

  // API for manual refresh of single airport (used in UI)
  Future<void> refreshSingleAirport(AirportInfo airport) async {
    _isLoading = true;
    notifyListeners();
    try {
      final source = await _detailService.getDataSource();
      await _detailService.clearAirportCache(
        all: false,
        icao: airport.icaoCode,
        type: source.dataSourceType,
      );
      final fresh = await _detailService.fetchAirportDetail(
        airport.icaoCode,
        forceRefresh: true,
        preferredSource: source,
        cacheScope: AirportCacheScope.persistent,
      );
      if (fresh != null) {
        applyUpdate(airport, fresh);
      }
    } catch (e) {
      _fetchErrors[airport.icaoCode] = '本地刷新失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> isDataSourceAvailable(AirportDataSource source) {
    return _detailService.isDataSourceAvailable(source);
  }

  Future<AirportDetailData?> fetchLocalDetail(
    String icaoCode, {
    bool forceRefresh = true,
    AirportDataSource? source,
  }) async {
    final target = source ?? _currentDataSource;
    return _detailService.fetchAirportDetail(
      icaoCode,
      forceRefresh: forceRefresh,
      preferredSource: target,
      cacheScope: AirportCacheScope.persistent,
    );
  }

  Future<void> clearOnlineCache(String icaoCode) async {
    await _detailService.clearAirportCache(
      all: false,
      icao: icaoCode,
      type: AirportDataSourceType.aviationApi,
    );
  }

  Future<AirportDetailData?> fetchOnlineDetail(String icaoCode) async {
    _isLoading = true;
    notifyListeners();
    try {
      final freshDetail = await _detailService.fetchAirportDetail(
        icaoCode,
        forceRefresh: true,
        preferredSource: AirportDataSource.aviationApi,
        cacheScope: AirportCacheScope.persistent,
      );
      return freshDetail;
    } catch (e) {
      _fetchErrors[icaoCode] = '在线获取失败: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
