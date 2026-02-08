class AircraftIdentity {
  final String id;
  final String manufacturer;
  final String family;
  final String model;
  final List<String> keywords;
  final List<String> icaos;
  final int? engineCount;
  final int? flapDetents;
  final double? wingAreaMin;
  final double? wingAreaMax;
  final bool generalAviation;

  const AircraftIdentity({
    required this.id,
    required this.manufacturer,
    required this.family,
    required this.model,
    required this.keywords,
    this.icaos = const [],
    this.engineCount,
    this.flapDetents,
    this.wingAreaMin,
    this.wingAreaMax,
    this.generalAviation = false,
  });

  String get displayName => '$manufacturer $model';
}

class AircraftMatch {
  final AircraftIdentity identity;
  final double score;

  const AircraftMatch({required this.identity, required this.score});
}

class AircraftCatalog {
  static const List<AircraftIdentity> entries = [
    AircraftIdentity(
      id: 'a319',
      manufacturer: 'Airbus',
      family: 'A320',
      model: 'A319',
      keywords: ['a319', 'airbus a319'],
      flapDetents: 4,
      engineCount: 2,
    ),
    AircraftIdentity(
      id: 'a320',
      manufacturer: 'Airbus',
      family: 'A320',
      model: 'A320',
      keywords: ['a320', 'airbus a320'],
      flapDetents: 4,
      engineCount: 2,
    ),
    AircraftIdentity(
      id: 'a321',
      manufacturer: 'Airbus',
      family: 'A320',
      model: 'A321',
      keywords: ['a321', 'airbus a321'],
      flapDetents: 4,
      engineCount: 2,
    ),
    AircraftIdentity(
      id: 'b737-800',
      manufacturer: 'Boeing',
      family: '737',
      model: '737-800',
      keywords: ['737-800', 'b737-800', 'boeing 737-800', 'zibo'],
      flapDetents: 8,
      engineCount: 2,
    ),
    AircraftIdentity(
      id: 'b737-max',
      manufacturer: 'Boeing',
      family: '737',
      model: '737 MAX',
      keywords: ['737 max', '737-8', '737-9', 'b737-8', 'b737-9', 'max'],
      flapDetents: 8,
      engineCount: 2,
    ),
    AircraftIdentity(
      id: 'b747-400',
      manufacturer: 'Boeing',
      family: '747',
      model: '747-400',
      keywords: ['747-400', 'b747-400', 'boeing 747-400'],
      engineCount: 4,
      flapDetents: 6,
    ),
    AircraftIdentity(
      id: 'b787-900',
      manufacturer: 'Boeing',
      family: '787',
      model: '787-900',
      keywords: ['787-900', 'b787-900', 'boeing 787-9', 'boeing 787'],
      engineCount: 2,
    ),
    AircraftIdentity(
      id: 'cessna-172',
      manufacturer: 'Cessna',
      family: 'Cessna',
      model: '172',
      keywords: ['cessna 172', 'c172', 'skyhawk'],
      engineCount: 1,
      generalAviation: true,
    ),
    AircraftIdentity(
      id: 'cessna-182',
      manufacturer: 'Cessna',
      family: 'Cessna',
      model: '182',
      keywords: ['cessna 182', 'c182', 'skylane'],
      engineCount: 1,
      generalAviation: true,
    ),
    AircraftIdentity(
      id: 'cirrus-sr22',
      manufacturer: 'Cirrus',
      family: 'SR',
      model: 'SR22',
      keywords: ['cirrus sr22', 'sr22'],
      engineCount: 1,
      generalAviation: true,
    ),
    AircraftIdentity(
      id: 'beechcraft-b58',
      manufacturer: 'Beechcraft',
      family: 'Baron',
      model: 'B58',
      keywords: ['baron', 'beechcraft baron', 'b58', 'be58', 'g58'],
      engineCount: 2,
      generalAviation: true,
    ),
    AircraftIdentity(
      id: 'diamond-da42',
      manufacturer: 'Diamond',
      family: 'DA',
      model: 'DA42',
      keywords: ['da42', 'diamond da42', 'twin star', 'twinstar'],
      engineCount: 2,
      generalAviation: true,
    ),
    AircraftIdentity(
      id: 'general-aviation',
      manufacturer: 'General',
      family: 'Aviation',
      model: 'Aviation Aircraft',
      keywords: [
        'cessna',
        'cirrus',
        'piper',
        'diamond',
        'general aviation',
        'ga',
      ],
      engineCount: 1,
      generalAviation: true,
    ),
  ];

  static AircraftMatch? match({
    String? title,
    String? icao,
    int? engineCount,
    int? flapDetents,
    double? wingArea,
  }) {
    if (title == null &&
        icao == null &&
        engineCount == null &&
        flapDetents == null &&
        wingArea == null) {
      return null;
    }

    final normalizedTitle = _normalize(title ?? '');
    final normalizedIcao = _normalize(icao ?? '');

    AircraftMatch? best;
    for (final entry in entries) {
      double score = 0;
      if (normalizedTitle.isNotEmpty) {
        for (final keyword in entry.keywords) {
          if (normalizedTitle.contains(keyword)) {
            score += 3;
          }
        }
      }
      if (normalizedIcao.isNotEmpty) {
        for (final code in entry.icaos) {
          if (normalizedIcao == _normalize(code)) {
            score += 4;
          }
        }
      }
      if (engineCount != null && entry.engineCount != null) {
        score += engineCount == entry.engineCount ? 1 : -1;
      }
      if (flapDetents != null && entry.flapDetents != null) {
        score += flapDetents == entry.flapDetents ? 1 : -1;
      }
      if (wingArea != null &&
          entry.wingAreaMin != null &&
          entry.wingAreaMax != null) {
        if (wingArea >= entry.wingAreaMin! && wingArea <= entry.wingAreaMax!) {
          score += 1;
        } else {
          score -= 1;
        }
      }
      if (score <= 0) continue;
      if (best == null || score > best.score) {
        best = AircraftMatch(identity: entry, score: score);
      }
    }

    return best;
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }
}
