import 'package:flutter/material.dart';
import '../models/airport_search_models.dart';
import '../services/airport_search_service.dart';

class AirportSearchProvider extends ChangeNotifier {
  AirportSearchProvider({AirportSearchService? service})
    : _service = service ?? AirportSearchService();

  final AirportSearchService _service;

  bool _isInitializing = false;
  bool _isSearching = false;
  bool _isUpdating = false;
  bool _isSuggesting = false;
  String? _errorKey;
  AirportQueryResult? _latestResult;
  List<FavoriteAirportEntry> _favorites = [];
  List<AirportSuggestionData> _suggestions = [];

  bool get isInitializing => _isInitializing;
  bool get isSearching => _isSearching;
  bool get isUpdating => _isUpdating;
  bool get isSuggesting => _isSuggesting;
  bool get isBusy => _isInitializing || _isSearching || _isUpdating;
  String? get errorKey => _errorKey;
  AirportQueryResult? get latestResult => _latestResult;
  List<FavoriteAirportEntry> get favorites => _favorites;
  List<AirportSuggestionData> get suggestions => _suggestions;

  bool isFavorite(String icao) {
    final normalized = _service.normalizeIcao(icao);
    return _favorites.any((item) => item.icao == normalized);
  }

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

  Future<void> queryAirport(String input) async {
    final normalized = _service.normalizeIcao(input);
    if (!_service.isValidIcao(normalized)) {
      _errorKey = 'invalidIcao';
      notifyListeners();
      return;
    }

    _isSearching = true;
    _suggestions = [];
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

  Future<void> updateSuggestions(String input) async {
    final normalized = _service.normalizeIcao(input);
    if (normalized.isEmpty) {
      _suggestions = [];
      _isSuggesting = false;
      notifyListeners();
      return;
    }
    if (!_service.isValidIcaoPartial(normalized)) {
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

  Future<void> querySuggestion(AirportSuggestionData suggestion) async {
    await queryAirport(suggestion.icao);
  }

  Future<void> toggleFavoriteForLatest() async {
    final result = _latestResult;
    if (result == null) return;
    final icao = result.airport.icao;
    final index = _favorites.indexWhere((item) => item.icao == icao);

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
      airportPayload: result.airport.payload,
      updatedAt: DateTime.now(),
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

  Future<void> refreshFavorite(String icao) async {
    final normalized = _service.normalizeIcao(icao);
    final index = _favorites.indexWhere((item) => item.icao == normalized);
    if (index < 0) return;

    _isUpdating = true;
    _errorKey = null;
    notifyListeners();

    try {
      final airport = await _service.fetchAirport(normalized);
      _favorites[index] = FavoriteAirportEntry(
        icao: normalized,
        airportPayload: airport.payload,
        updatedAt: DateTime.now(),
      );
      _favorites.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      await _service.saveFavorites(_favorites);
      if (_latestResult?.airport.icao == normalized) {
        _latestResult = AirportQueryResult(
          airport: airport,
          metar: _latestResult!.metar,
        );
      }
    } catch (_) {
      _errorKey = 'favoriteUpdateFailed';
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<void> selectFavoriteAndQuery(String icao) async {
    await queryAirport(icao);
  }

  void clearError() {
    if (_errorKey == null) return;
    _errorKey = null;
    notifyListeners();
  }
}
