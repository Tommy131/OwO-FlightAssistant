import 'dart:convert';
import '../../../core/services/persistence_service.dart';
import '../../http/http_module.dart';
import '../models/airport_search_models.dart';

class AirportSearchService {
  static const String _moduleName = 'airport_search';
  static const String _favoritesKey = 'favorite_airports';
  static final RegExp _icaoPattern = RegExp(r'^[A-Z0-9]{4}$');
  static final RegExp _icaoPartialPattern = RegExp(r'^[A-Z0-9]{1,4}$');

  final PersistenceService _persistence;

  AirportSearchService({PersistenceService? persistence})
    : _persistence = persistence ?? PersistenceService();

  String normalizeIcao(String input) => input.trim().toUpperCase();

  bool isValidIcao(String input) {
    return _icaoPattern.hasMatch(normalizeIcao(input));
  }

  bool isValidIcaoPartial(String input) {
    return _icaoPartialPattern.hasMatch(normalizeIcao(input));
  }

  Future<AirportQueryResult> queryAirportAndMetar(String icao) async {
    final normalized = normalizeIcao(icao);
    if (!isValidIcao(normalized)) {
      throw const FormatException('invalid_icao');
    }

    final responses = await Future.wait([
      HttpModule.client.getAirportByIcao(normalized),
      HttpModule.client.getMetarByIcao(normalized),
    ]);

    final airportData = _decodeBodyToMap(responses[0].body);
    final metarData = _decodeBodyToMap(responses[1].body);

    return AirportQueryResult(
      airport: AirportDetailData.fromApi(airportData),
      metar: MetarData.fromApi(metarData),
    );
  }

  Future<AirportDetailData> fetchAirport(String icao) async {
    final normalized = normalizeIcao(icao);
    if (!isValidIcao(normalized)) {
      throw const FormatException('invalid_icao');
    }

    final response = await HttpModule.client.getAirportByIcao(normalized);
    final airportData = _decodeBodyToMap(response.body);
    return AirportDetailData.fromApi(airportData);
  }

  Future<List<AirportSuggestionData>> suggestAirports(
    String query, {
    int limit = 8,
  }) async {
    final normalized = normalizeIcao(query);
    if (!isValidIcaoPartial(normalized)) {
      return [];
    }
    final response = await HttpModule.client.getAirportSuggestions(
      normalized,
      limit: limit,
    );
    final root = _decodeBodyToMap(response.body);
    final result = _asMap(root['result']) ?? root;
    final list =
        _asList(result['suggestions']) ?? _asList(result['items']) ?? [];
    return list
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry('$k', v)))
        .map(AirportSuggestionData.fromApi)
        .where((item) => item.icao.isNotEmpty)
        .toList();
  }

  Future<List<FavoriteAirportEntry>> loadFavorites() async {
    await _persistence.ensureReady();
    final raw = _persistence.getModuleData<List<dynamic>>(
      _moduleName,
      _favoritesKey,
    );
    if (raw == null || raw.isEmpty) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry('$k', v)))
        .map(FavoriteAirportEntry.fromJson)
        .where((item) => item.icao.isNotEmpty && isValidIcao(item.icao))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> saveFavorites(List<FavoriteAirportEntry> favorites) async {
    await _persistence.ensureReady();
    final payload = favorites.map((item) => item.toJson()).toList();
    await _persistence.setModuleData(_moduleName, _favoritesKey, payload);
  }

  Map<String, dynamic> _decodeBodyToMap(String body) {
    final decoded = json.decode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
    throw const FormatException('invalid_response');
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry('$key', val));
    }
    return null;
  }

  List<dynamic>? _asList(dynamic value) {
    if (value is List<dynamic>) return value;
    if (value is List) {
      return value.cast<dynamic>();
    }
    return null;
  }
}
