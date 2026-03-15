import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../core/services/persistence_service.dart';
import '../../airport_search/models/airport_search_models.dart';
import '../../airport_search/services/airport_search_service.dart';

class BriefingRecord {
  final String title;
  final String content;
  final DateTime createdAt;
  final String? sourceFilePath;

  const BriefingRecord({
    required this.title,
    required this.content,
    required this.createdAt,
    this.sourceFilePath,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

  factory BriefingRecord.fromJson(Map<String, dynamic> json) => BriefingRecord(
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );

  BriefingRecord copyWith({
    String? title,
    String? content,
    DateTime? createdAt,
    String? sourceFilePath,
  }) {
    return BriefingRecord(
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      sourceFilePath: sourceFilePath ?? this.sourceFilePath,
    );
  }
}

class BriefingProvider extends ChangeNotifier {
  final AirportSearchService _airportService = AirportSearchService();
  bool _isLoading = false;
  BriefingRecord? _latest;
  final List<BriefingRecord> _history = [];

  bool get isLoading => _isLoading;
  BriefingRecord? get latest => _latest;
  List<BriefingRecord> get history => List.unmodifiable(_history);

  BriefingProvider() {
    _init();
  }

  Future<void> _init() async {
    await reloadFromDirectory();
  }

  Future<void> generateBriefing({
    required String departure,
    required String arrival,
    String? alternate,
    String? flightNumber,
    String? route,
    int? cruiseAltitude,
    String? departureRunway,
    String? arrivalRunway,
    String? alternateRunway,
  }) async {
    _isLoading = true;
    notifyListeners();
    final generatedAt = DateTime.now();
    final normalizedDeparture = departure.trim().toUpperCase();
    final normalizedArrival = arrival.trim().toUpperCase();
    final normalizedAlternate = alternate?.trim().toUpperCase() ?? '';
    final routeText = route != null && route.trim().isNotEmpty
        ? route.trim().toUpperCase()
        : 'DCT';
    final cruise = cruiseAltitude ?? 35000;
    final flightNo = flightNumber != null && flightNumber.trim().isNotEmpty
        ? flightNumber.trim().toUpperCase()
        : _generateFlightNumber();
    try {
      final depBundle = await _fetchAirportBundle(normalizedDeparture);
      final arrBundle = await _fetchAirportBundle(normalizedArrival);
      final altBundle = normalizedAlternate.isEmpty
          ? null
          : await _fetchAirportBundle(normalizedAlternate);
      final distanceNm = _calculateDistanceNm(
        depBundle.airport.latitude,
        depBundle.airport.longitude,
        arrBundle.airport.latitude,
        arrBundle.airport.longitude,
      );
      final estimatedMinutes = distanceNm != null
          ? ((distanceNm / 450.0) * 60).round()
          : null;
      final fuel = _buildFuelPlan(
        distanceNm: distanceNm,
        hasAlternate: altBundle != null,
      );
      final depRunway =
          (departureRunway != null && departureRunway.trim().isNotEmpty)
          ? departureRunway.trim().toUpperCase()
          : _selectBestRunway(depBundle.airport, depBundle.metar);
      final arrRunway = (arrivalRunway != null && arrivalRunway.trim().isNotEmpty)
          ? arrivalRunway.trim().toUpperCase()
          : _selectBestRunway(arrBundle.airport, arrBundle.metar);
      final altRunway =
          altBundle == null
          ? null
          : (alternateRunway != null && alternateRunway.trim().isNotEmpty)
          ? alternateRunway.trim().toUpperCase()
          : _selectBestRunway(altBundle.airport, altBundle.metar);
      final summary = _buildBriefingSummary(
        generatedAt: generatedAt,
        flightNo: flightNo,
        departure: depBundle,
        arrival: arrBundle,
        alternate: altBundle,
        route: routeText,
        cruiseAltitude: cruise,
        distanceNm: distanceNm,
        estimatedMinutes: estimatedMinutes,
        depRunway: depRunway,
        arrRunway: arrRunway,
        altRunway: altRunway,
        fuel: fuel,
      );
      final record = BriefingRecord(
        title: '${depBundle.airport.icao} → ${arrBundle.airport.icao}',
        content: summary,
        createdAt: generatedAt,
      );
      final savedRecord = await _saveRecord(record);
      _latest = savedRecord;
      _history.insert(0, savedRecord);
    } catch (_) {
      final fallback = StringBuffer()
        ..writeln('FLT: $flightNo')
        ..writeln('GEN: ${_formatDateTime(generatedAt)}')
        ..writeln('DEP: $normalizedDeparture')
        ..writeln('ARR: $normalizedArrival')
        ..writeln(
          'ALT: ${normalizedAlternate.isEmpty ? "--" : normalizedAlternate}',
        )
        ..writeln('RTE: $routeText')
        ..writeln('CRZ: FL${(cruise / 100).round()}')
        ..writeln('DIST: --')
        ..writeln('EET: --')
        ..writeln(
          'DEP RWY: ${departureRunway != null && departureRunway.trim().isNotEmpty ? departureRunway.trim().toUpperCase() : "--"}',
        )
        ..writeln(
          'ARR RWY: ${arrivalRunway != null && arrivalRunway.trim().isNotEmpty ? arrivalRunway.trim().toUpperCase() : "--"}',
        )
        ..writeln(
          'ALT RWY: ${normalizedAlternate.isEmpty ? "--" : (alternateRunway != null && alternateRunway.trim().isNotEmpty ? alternateRunway.trim().toUpperCase() : "--")}',
        )
        ..writeln('DEP WX: NO METAR')
        ..writeln('ARR WX: NO METAR')
        ..writeln('ALT WX: ${normalizedAlternate.isEmpty ? "--" : "NO METAR"}')
        ..writeln('TRIP FUEL: --')
        ..writeln('TOTAL FUEL: --');
      final fallbackRecord = BriefingRecord(
        title: '$normalizedDeparture → $normalizedArrival',
        content: fallback.toString(),
        createdAt: generatedAt,
      );
      final savedRecord = await _saveRecord(fallbackRecord);
      _latest = savedRecord;
      _history.insert(0, savedRecord);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<_AirportBundle> _fetchAirportBundle(String icao) async {
    try {
      final result = await _airportService.queryAirportAndMetar(icao);
      return _AirportBundle(airport: result.airport, metar: result.metar);
    } catch (_) {
      final airport = await _airportService.fetchAirport(icao);
      return _AirportBundle(airport: airport, metar: null);
    }
  }

  String _buildBriefingSummary({
    required DateTime generatedAt,
    required String flightNo,
    required _AirportBundle departure,
    required _AirportBundle arrival,
    required _AirportBundle? alternate,
    required String route,
    required int cruiseAltitude,
    required double? distanceNm,
    required int? estimatedMinutes,
    required String? depRunway,
    required String? arrRunway,
    required String? altRunway,
    required _FuelPlan fuel,
  }) {
    final buffer = StringBuffer()
      ..writeln('FLT: $flightNo')
      ..writeln('GEN: ${_formatDateTime(generatedAt)}')
      ..writeln('DEP: ${_formatAirportLine(departure.airport)}')
      ..writeln('ARR: ${_formatAirportLine(arrival.airport)}')
      ..writeln(
        'ALT: ${alternate == null ? "--" : _formatAirportLine(alternate.airport)}',
      )
      ..writeln('RTE: $route')
      ..writeln('CRZ: FL${(cruiseAltitude / 100).round()}')
      ..writeln(
        'DIST: ${distanceNm != null ? "${distanceNm.toStringAsFixed(0)} NM" : "--"}',
      )
      ..writeln(
        'EET: ${estimatedMinutes != null ? _formatDuration(estimatedMinutes) : "--"}',
      )
      ..writeln('DEP RWY: ${depRunway ?? "--"}')
      ..writeln('ARR RWY: ${arrRunway ?? "--"}')
      ..writeln('ALT RWY: ${altRunway ?? "--"}')
      ..writeln('DEP WX: ${_formatWeatherLine(departure.metar)}')
      ..writeln('ARR WX: ${_formatWeatherLine(arrival.metar)}')
      ..writeln(
        'ALT WX: ${alternate == null ? "--" : _formatWeatherLine(alternate.metar)}',
      )
      ..writeln('TRIP FUEL: ${fuel.trip.toStringAsFixed(0)} KG')
      ..writeln('ALTN FUEL: ${fuel.alternate.toStringAsFixed(0)} KG')
      ..writeln('RESV FUEL: ${fuel.reserve.toStringAsFixed(0)} KG')
      ..writeln('TAXI FUEL: ${fuel.taxi.toStringAsFixed(0)} KG')
      ..writeln('EXTRA FUEL: ${fuel.extra.toStringAsFixed(0)} KG')
      ..writeln('TOTAL FUEL: ${fuel.total.toStringAsFixed(0)} KG')
      ..writeln('AVG FLOW: ${fuel.avgFlow.toStringAsFixed(0)} KG/H')
      ..writeln('ETA FUEL: ${fuel.estimatedArrivalFuel.toStringAsFixed(0)} KG');
    return buffer.toString();
  }

  _FuelPlan _buildFuelPlan({
    required double? distanceNm,
    required bool hasAlternate,
  }) {
    final trip = (distanceNm ?? 0) * 2.5;
    final alternate = hasAlternate ? 200 * 2.5 : 0.0;
    const reserve = 1500.0;
    const taxi = 200.0;
    final extra = trip * 0.05;
    final total = trip + alternate + reserve + taxi + extra;
    final estimatedArrivalFuel = reserve + alternate;
    final avgFlow = distanceNm == null || distanceNm <= 0
        ? 2600.0
        : (trip / (distanceNm / 450.0)).clamp(1800.0, 3400.0);
    return _FuelPlan(
      trip: trip,
      alternate: alternate,
      reserve: reserve,
      taxi: taxi,
      extra: extra,
      total: total,
      avgFlow: avgFlow,
      estimatedArrivalFuel: estimatedArrivalFuel,
    );
  }

  double? _calculateDistanceNm(
    double? lat1,
    double? lon1,
    double? lat2,
    double? lon2,
  ) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return null;
    }
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final km = earthRadiusKm * c;
    return km * 0.539957;
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  String _formatAirportLine(AirportDetailData airport) {
    final name = airport.name?.trim();
    final city = airport.city?.trim();
    final country = airport.country?.trim();
    final pieces = <String>[
      airport.icao,
      if (name != null && name.isNotEmpty) name,
      if (city != null && city.isNotEmpty) city,
      if (country != null && country.isNotEmpty) country,
    ];
    return pieces.join(' | ');
  }

  String _formatWeatherLine(MetarData? metar) {
    if (metar == null ||
        ((metar.raw ?? '').isEmpty && (metar.decoded ?? '').isEmpty)) {
      return 'NO METAR';
    }
    final raw = (metar.raw ?? '').trim();
    final decoded = (metar.decoded ?? '').trim();
    final source = raw.isNotEmpty ? raw : decoded;
    final wind = RegExp(
      r'\b(\d{3}|VRB)(\d{2,3})G?(\d{2,3})?KT\b',
    ).firstMatch(source);
    final vis = RegExp(r'\b(\d{4})\b').firstMatch(source);
    final temp = RegExp(r'\b(M?\d{2})/(M?\d{2})\b').firstMatch(source);
    final qnh = RegExp(r'\bQ(\d{4})\b').firstMatch(source);
    final pieces = <String>[
      if (wind != null)
        'WIND ${wind.group(1)}${wind.group(2)}KT${wind.group(3) != null ? " G${wind.group(3)}" : ""}',
      if (vis != null) 'VIS ${vis.group(1)}m',
      if (temp != null) 'TEMP ${temp.group(1)}/${temp.group(2)}',
      if (qnh != null) 'QNH ${qnh.group(1)}',
    ];
    if (pieces.isNotEmpty) {
      return pieces.join(' · ');
    }
    return raw.isNotEmpty ? raw : decoded;
  }

  String? _selectBestRunway(AirportDetailData airport, MetarData? metar) {
    if (airport.runways.isEmpty) return null;
    final windDirection = _parseWindDirection(
      metar?.raw ?? metar?.decoded ?? '',
    );
    if (windDirection == null) {
      return airport.runways.first.ident;
    }
    String? best;
    var minDiff = 180;
    for (final runway in airport.runways) {
      final parts = runway.ident
          .split('/')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty);
      for (final part in parts) {
        final heading = _parseRunwayHeading(part);
        if (heading == null) continue;
        final diff = (windDirection - heading).abs();
        final normalized = diff > 180 ? 360 - diff : diff;
        if (normalized < minDiff) {
          minDiff = normalized;
          best = part;
        }
      }
    }
    return best ?? airport.runways.first.ident;
  }

  int? _parseWindDirection(String source) {
    final match = RegExp(
      r'\b(\d{3}|VRB)\d{2,3}(?:G\d{2,3})?KT\b',
    ).firstMatch(source);
    if (match == null) return null;
    final group = match.group(1);
    if (group == null || group == 'VRB') return null;
    return int.tryParse(group);
  }

  int? _parseRunwayHeading(String runway) {
    final value = runway.toUpperCase().replaceAll(RegExp(r'[^0-9]'), '');
    final runwayNum = int.tryParse(value);
    if (runwayNum == null) return null;
    return (runwayNum % 36) * 10;
  }

  String _formatDateTime(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}H ${m.toString().padLeft(2, '0')}M';
  }

  String _generateFlightNumber() {
    final random = math.Random();
    return 'CA${1000 + random.nextInt(9000)}';
  }

  Future<bool> deleteBriefing(BriefingRecord record) async {
    try {
      final deleted = await _removeRecordFromStorage(record);
      if (!deleted) {
        return false;
      }
      _history.removeWhere(
        (item) =>
            item.createdAt == record.createdAt &&
            item.title == record.title &&
            item.content == record.content,
      );
      _latest = _history.isNotEmpty ? _history.first : null;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> reloadFromDirectory() async {
    _isLoading = true;
    notifyListeners();
    final dir = await _ensureDirectory();
    if (dir == null) {
      _history.clear();
      _latest = null;
      _isLoading = false;
      notifyListeners();
      return 0;
    }
    final entries = await dir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.json')
        .toList();
    final List<BriefingRecord> loaded = [];
    for (final file in entries) {
      final fileRecords = await _loadFromFile(file);
      if (fileRecords.isNotEmpty) {
        loaded.addAll(fileRecords);
      }
    }
    loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _history
      ..clear()
      ..addAll(loaded);
    _latest = _history.isNotEmpty ? _history.first : null;
    _isLoading = false;
    notifyListeners();
    return loaded.length;
  }

  Future<int> importFromFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final filePath = result?.files.single.path;
    if (filePath == null) return 0;
    final records = await _loadFromFile(File(filePath));
    if (records.isEmpty) return 0;
    for (final record in records) {
      await _saveRecord(record);
    }
    await reloadFromDirectory();
    return records.length;
  }

  Future<int> exportToFilePicker() async {
    if (_history.isEmpty) return -1;
    final filePath = await FilePicker.platform.saveFile(
      fileName: 'flight_briefings_export.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (filePath == null) return 0;
    final payload = _history.map((record) => record.toJson()).toList();
    await File(
      filePath,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return 1;
  }

  Future<Directory?> _ensureDirectory() async {
    final persistence = PersistenceService();
    await persistence.ensureReady();
    final rootPath = persistence.rootPath;
    if (rootPath == null) return null;
    final dir = Directory(p.join(rootPath, 'flight_briefings'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<BriefingRecord> _saveRecord(BriefingRecord record) async {
    final dir = await _ensureDirectory();
    if (dir == null) return record;
    final fileName = 'briefing_${record.createdAt.millisecondsSinceEpoch}.json';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(record.toJson()),
    );
    return record.copyWith(sourceFilePath: file.path);
  }

  Future<List<BriefingRecord>> _loadFromFile(File file) async {
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return [
          BriefingRecord.fromJson(decoded).copyWith(sourceFilePath: file.path),
        ];
      }
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(BriefingRecord.fromJson)
            .map((record) => record.copyWith(sourceFilePath: file.path))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> _removeRecordFromStorage(BriefingRecord record) async {
    final filePath = record.sourceFilePath;
    if (filePath == null || filePath.isEmpty) return false;
    final file = File(filePath);
    if (!await file.exists()) return false;
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      await file.delete();
      return true;
    }
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) {
      if (_isSameRecord(decoded, record)) {
        await file.delete();
        return true;
      }
      return false;
    }
    if (decoded is List) {
      final remaining = decoded
          .whereType<Map<String, dynamic>>()
          .where((item) => !_isSameRecord(item, record))
          .toList();
      if (remaining.length ==
          decoded.whereType<Map<String, dynamic>>().length) {
        return false;
      }
      if (remaining.isEmpty) {
        await file.delete();
      } else {
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(remaining),
        );
      }
      return true;
    }
    return false;
  }

  bool _isSameRecord(Map<String, dynamic> json, BriefingRecord record) {
    final candidate = BriefingRecord.fromJson(json);
    return candidate.title == record.title &&
        candidate.content == record.content &&
        candidate.createdAt.toIso8601String() ==
            record.createdAt.toIso8601String();
  }
}

class _AirportBundle {
  final AirportDetailData airport;
  final MetarData? metar;

  const _AirportBundle({required this.airport, this.metar});
}

class _FuelPlan {
  final double trip;
  final double alternate;
  final double reserve;
  final double taxi;
  final double extra;
  final double total;
  final double avgFlow;
  final double estimatedArrivalFuel;

  const _FuelPlan({
    required this.trip,
    required this.alternate,
    required this.reserve,
    required this.taxi,
    required this.extra,
    required this.total,
    required this.avgFlow,
    required this.estimatedArrivalFuel,
  });
}
