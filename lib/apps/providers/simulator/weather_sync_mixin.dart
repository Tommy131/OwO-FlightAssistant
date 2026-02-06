import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/weather_service.dart';
import '../../data/airports_database.dart';

mixin WeatherSyncMixin on ChangeNotifier {
  final WeatherService _weatherService = WeatherService();
  final Map<String, MetarData> _metarCache = {};
  final Map<String, String> _metarErrors = {};
  DateTime? _lastWeatherFetch;
  int _cachedMetarExpiry = 60;
  DateTime? _lastExpiryCheck;
  String? _lastNearestIcao;

  Map<String, MetarData> get metarCache => _metarCache;
  Map<String, String> get metarErrors => _metarErrors;

  Future<void> fetchRequiredMetars({
    AirportInfo? nearest,
    AirportInfo? destination,
    AirportInfo? alternate,
  }) async {
    final now = DateTime.now();
    final icaoList = <String>{};

    if (nearest != null) icaoList.add(nearest.icaoCode);
    if (destination != null) icaoList.add(destination.icaoCode);
    if (alternate != null) icaoList.add(alternate.icaoCode);

    if (icaoList.isEmpty) return;

    bool updated = false;
    final prefs = await SharedPreferences.getInstance();
    final expiryMinutes = prefs.getInt('metar_cache_expiry') ?? 60;

    for (final icao in icaoList) {
      final cached = _weatherService.getCachedMetar(icao);
      if (cached == null || cached.isExpired(expiryMinutes)) {
        try {
          final data = await _weatherService.fetchMetar(icao);
          if (data != null) {
            _metarCache[icao] = data;
            _metarErrors.remove(icao);
            updated = true;
          } else {
            _metarErrors[icao] = '无法获取气象报文';
            updated = true;
          }
        } catch (e) {
          _metarErrors[icao] = '气象报文获取失败: $e';
          updated = true;
        }
      } else if (_metarCache[icao] != cached) {
        // 如果 Service 中有更新的缓存，同步到本地
        _metarCache[icao] = cached;
        _metarErrors.remove(icao);
        updated = true;
      }
    }

    if (updated) {
      _lastWeatherFetch = now;
      notifyListeners();
    }
  }

  Future<void> syncWeatherState({
    AirportInfo? nearest,
    AirportInfo? destination,
    AirportInfo? alternate,
  }) async {
    final now = DateTime.now();

    if (_lastWeatherFetch != null &&
        now.difference(_lastWeatherFetch!).inSeconds < 10) {
      if (nearest != null && nearest.icaoCode != _lastNearestIcao) {
        _lastNearestIcao = nearest.icaoCode;
        fetchRequiredMetars(
          nearest: nearest,
          destination: destination,
          alternate: alternate,
        );
      }
      return;
    }

    if (_lastExpiryCheck == null ||
        now.difference(_lastExpiryCheck!).inSeconds > 30) {
      final prefs = await SharedPreferences.getInstance();
      _cachedMetarExpiry = prefs.getInt('metar_cache_expiry') ?? 60;
      _lastExpiryCheck = now;
    }

    bool needsRefresh = false;
    if (nearest != null && nearest.icaoCode != _lastNearestIcao) {
      _lastNearestIcao = nearest.icaoCode;
      needsRefresh = true;
    }

    if (!needsRefresh) {
      if (nearest != null) {
        final cached = _weatherService.getCachedMetar(nearest.icaoCode);
        if (cached == null || cached.isExpired(_cachedMetarExpiry)) {
          needsRefresh = true;
        }
      }
      if (!needsRefresh && destination != null) {
        final cached = _weatherService.getCachedMetar(destination.icaoCode);
        if (cached == null || cached.isExpired(_cachedMetarExpiry)) {
          needsRefresh = true;
        }
      }
    }

    if (needsRefresh) {
      fetchRequiredMetars(
        nearest: nearest,
        destination: destination,
        alternate: alternate,
      );
    }
  }
}
