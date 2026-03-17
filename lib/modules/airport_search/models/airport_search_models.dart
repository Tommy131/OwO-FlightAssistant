class AirportDetailData {
  final Map<String, dynamic> payload;
  final String icao;
  final String? iata;
  final String? name;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
  final int? elevationFt;
  final String? source;
  final String? airac;
  final List<AirportRunwayData> runways;
  final List<AirportParkingData> parkings;
  final List<AirportFrequencyData> frequencies;

  const AirportDetailData({
    required this.payload,
    required this.icao,
    this.iata,
    this.name,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.elevationFt,
    this.source,
    this.airac,
    this.runways = const [],
    this.parkings = const [],
    this.frequencies = const [],
  });

  factory AirportDetailData.fromApi(Map<String, dynamic> data) {
    final payloadRoot = _asMap(_pick(data, ['data'])) ?? data;
    var detail = _asMap(
      _pick(payloadRoot, ['airport_detail', 'airportDetail', 'AirportDetail']),
    );
    if (detail == null &&
        (_pick(payloadRoot, ['airport', 'Airport']) != null ||
            _pick(payloadRoot, ['sources', 'Sources']) != null)) {
      detail = payloadRoot;
    }
    final airport = _asMap(_pick(detail, ['airport', 'Airport']));
    final runways = _asListOfMaps(
      _pick(detail, ['runways', 'Runways']),
    ).map(AirportRunwayData.fromApi).toList();
    final parkings = _asListOfMaps(
      _pick(detail, [
        'parkings',
        'Parkings',
        'parking_spots',
        'parkingSpots',
        'parking_points',
      ]),
    ).map(AirportParkingData.fromApi).toList();
    final frequencies = _asListOfMaps(
      _pick(detail, ['frequencies', 'Frequencies']),
    ).map(AirportFrequencyData.fromApi).toList();
    final icao =
        _readString(_pick(airport, ['icao', 'ICAO'])) ??
        _readString(_pick(detail, ['icao', 'ICAO'])) ??
        _readString(_pick(payloadRoot, ['icao', 'ICAO'])) ??
        '';

    return AirportDetailData(
      payload: Map<String, dynamic>.from(data),
      icao: icao.toUpperCase(),
      iata: _readString(_pick(airport, ['iata', 'IATA'])),
      name:
          _readString(_pick(airport, ['name', 'Name'])) ??
          _readString(_pick(detail, ['name', 'Name'])),
      city:
          _readString(_pick(airport, ['city', 'City'])) ??
          _readString(_pick(detail, ['city', 'City'])),
      country:
          _readString(_pick(airport, ['country', 'Country'])) ??
          _readString(_pick(detail, ['country', 'Country'])),
      latitude:
          _readDouble(_pick(airport, ['latitude', 'lat', 'Lat'])) ??
          _readDouble(_pick(payloadRoot, ['lat', 'latitude', 'Lat'])),
      longitude:
          _readDouble(_pick(airport, ['longitude', 'lon', 'lng', 'Lon'])) ??
          _readDouble(_pick(payloadRoot, ['lng', 'lon', 'longitude', 'Lon'])),
      elevationFt:
          _readInt(_pick(airport, ['elevation', 'Elevation'])) ??
          _readInt(_pick(payloadRoot, ['elevation', 'Elevation'])),
      source:
          _readString(
            _pick(payloadRoot, ['database_source', 'source', 'Source']),
          ) ??
          _readString(_pick(airport, ['source', 'Source'])) ??
          _readString(_pick(detail, ['data_source', 'source', 'Source'])),
      airac:
          _readString(_pick(payloadRoot, ['airac', 'AIRAC'])) ??
          _readString(_pick(detail, ['airac', 'AIRAC'])),
      runways: runways,
      parkings: parkings,
      frequencies: frequencies,
    );
  }
}

class AirportRunwayData {
  final String ident;
  final double? lengthM;
  final String? surface;
  final String? leIdent;
  final String? heIdent;
  final double? leLat;
  final double? leLon;
  final double? heLat;
  final double? heLon;

  const AirportRunwayData({
    required this.ident,
    this.lengthM,
    this.surface,
    this.leIdent,
    this.heIdent,
    this.leLat,
    this.leLon,
    this.heLat,
    this.heLon,
  });

  factory AirportRunwayData.fromApi(Map<String, dynamic> data) {
    return AirportRunwayData(
      ident:
          _readString(_pick(data, ['ident', 'Ident', 'name', 'Name'])) ?? '-',
      lengthM: _readDouble(_pick(data, ['length_m', 'lengthM', 'LengthM'])),
      surface: _readString(_pick(data, ['surface', 'Surface', 'type', 'Type'])),
      leIdent: _readString(_pick(data, ['le_ident', 'leIdent', 'LeIdent'])),
      heIdent: _readString(_pick(data, ['he_ident', 'heIdent', 'HeIdent'])),
      leLat: _readDouble(_pick(data, ['le_lat', 'leLat', 'LeLat'])),
      leLon: _readDouble(_pick(data, ['le_lon', 'leLon', 'LeLon'])),
      heLat: _readDouble(_pick(data, ['he_lat', 'heLat', 'HeLat'])),
      heLon: _readDouble(_pick(data, ['he_lon', 'heLon', 'HeLon'])),
    );
  }
}

class AirportParkingData {
  final String? name;
  final double? latitude;
  final double? longitude;
  final double? headingDeg;

  const AirportParkingData({
    this.name,
    this.latitude,
    this.longitude,
    this.headingDeg,
  });

  factory AirportParkingData.fromApi(Map<String, dynamic> data) {
    return AirportParkingData(
      name: _readString(_pick(data, ['name', 'Name', 'ident', 'Ident'])),
      latitude: _readDouble(_pick(data, ['lat', 'latitude', 'Lat'])),
      longitude: _readDouble(_pick(data, ['lon', 'lng', 'longitude', 'Lon'])),
      headingDeg: _readDouble(
        _pick(data, ['heading_deg', 'headingDeg', 'heading', 'Heading']),
      ),
    );
  }
}

class AirportFrequencyData {
  final String? type;
  final String? value;

  const AirportFrequencyData({this.type, this.value});

  factory AirportFrequencyData.fromApi(Map<String, dynamic> data) {
    return AirportFrequencyData(
      type: _readString(_pick(data, ['type', 'Type'])),
      value: _readString(_pick(data, ['frequency', 'Frequency', 'value'])),
    );
  }
}

class MetarData {
  final String? raw;
  final String? decoded;
  final String? wind;
  final String? visibility;
  final String? temperature;
  final String? altimeter;

  const MetarData({
    this.raw,
    this.decoded,
    this.wind,
    this.visibility,
    this.temperature,
    this.altimeter,
  });

  factory MetarData.fromApi(Map<String, dynamic> data) {
    final payloadRoot = _asMap(_pick(data, ['data'])) ?? data;
    return MetarData(
      raw: _readString(
        _pick(payloadRoot, ['raw_metar', 'raw', 'Raw', 'metar']),
      ),
      decoded: _readString(
        _pick(payloadRoot, [
          'translated_metar',
          'decoded',
          'Decoded',
          'translatedMetar',
        ]),
      ),
      wind: _readString(_pick(payloadRoot, ['display_wind', 'wind'])),
      visibility: _readString(
        _pick(payloadRoot, ['display_visibility', 'visibility']),
      ),
      temperature: _readString(
        _pick(payloadRoot, ['display_temperature', 'temperature']),
      ),
      altimeter: _readString(
        _pick(payloadRoot, ['display_altimeter', 'altimeter']),
      ),
    );
  }
}

class AirportQueryResult {
  final AirportDetailData airport;
  final MetarData metar;

  const AirportQueryResult({required this.airport, required this.metar});
}

class AirportSuggestionData {
  final String icao;
  final String? name;
  final String? source;

  const AirportSuggestionData({required this.icao, this.name, this.source});

  factory AirportSuggestionData.fromApi(Map<String, dynamic> data) {
    final icao =
        _readString(_pick(data, ['icao', 'ICAO']))?.toUpperCase() ?? '';
    return AirportSuggestionData(
      icao: icao,
      name: _readString(_pick(data, ['name', 'Name'])),
      source: _readString(_pick(data, ['source', 'Source'])),
    );
  }
}

class FavoriteAirportEntry {
  final String icao;
  final Map<String, dynamic> airportPayload;
  final DateTime updatedAt;

  const FavoriteAirportEntry({
    required this.icao,
    required this.airportPayload,
    required this.updatedAt,
  });

  AirportDetailData get airport => AirportDetailData.fromApi(airportPayload);

  Map<String, dynamic> toJson() {
    return {
      'icao': icao,
      'airport_payload': airportPayload,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FavoriteAirportEntry.fromJson(Map<String, dynamic> json) {
    final updatedAtRaw = _readString(json['updated_at']);
    return FavoriteAirportEntry(
      icao: (_readString(json['icao']) ?? '').toUpperCase(),
      airportPayload: _asMap(json['airport_payload']) ?? const {},
      updatedAt: DateTime.tryParse(updatedAtRaw ?? '') ?? DateTime.now(),
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry('$key', val));
  }
  return null;
}

List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => _asMap(item))
      .whereType<Map<String, dynamic>>()
      .toList();
}

String? _readString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? _readDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

dynamic _pick(Map<String, dynamic>? map, List<String> keys) {
  if (map == null) return null;
  for (final key in keys) {
    if (map.containsKey(key)) {
      return map[key];
    }
  }
  for (final key in keys) {
    for (final entry in map.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase()) {
        return entry.value;
      }
    }
  }
  return null;
}
