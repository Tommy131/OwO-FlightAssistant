class FlapProfile {
  final List<String> labels;
  final List<double>? angles;
  final double maxAngle;

  const FlapProfile({required this.labels, this.angles, this.maxAngle = 40.0});
}

class LightProfile {
  final List<int>? landingIndices;
  final int? taxiIndex;
  final int? logoIndex;
  final List<int>? logoIndices;
  final int? wingIndex;
  final int? runwayLeftIndex;
  final int? runwayRightIndex;
  final int? wheelWellIndex;
  final bool hasMainLandingLightControl;

  const LightProfile({
    this.landingIndices,
    this.taxiIndex,
    this.logoIndex,
    this.logoIndices,
    this.wingIndex,
    this.runwayLeftIndex,
    this.runwayRightIndex,
    this.wheelWellIndex,
    this.hasMainLandingLightControl = false,
  });
}

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
  final FlapProfile? flapProfile;
  final LightProfile? lightProfile;

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
    this.flapProfile,
    this.lightProfile,
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
      flapProfile: FlapProfile(
        labels: ['UP', '1', '2', '3', 'FULL'],
        maxAngle: 40,
      ),
    ),
    AircraftIdentity(
      id: 'a320',
      manufacturer: 'Airbus',
      family: 'A320',
      model: 'A320',
      keywords: ['a320', 'airbus a320'],
      flapDetents: 4,
      engineCount: 2,
      flapProfile: FlapProfile(
        labels: ['UP', '1', '2', '3', 'FULL'],
        maxAngle: 40,
      ),
    ),
    AircraftIdentity(
      id: 'a321',
      manufacturer: 'Airbus',
      family: 'A320',
      model: 'A321',
      keywords: ['a321', 'airbus a321'],
      flapDetents: 4,
      engineCount: 2,
      flapProfile: FlapProfile(
        labels: ['UP', '1', '2', '3', 'FULL'],
        maxAngle: 40,
      ),
    ),
    AircraftIdentity(
      id: 'b737-800',
      manufacturer: 'Boeing',
      family: '737',
      model: '737-800',
      keywords: ['737-800', 'b737-800', 'boeing 737-800', 'zibo'],
      flapDetents: 8,
      engineCount: 2,
      flapProfile: FlapProfile(
        labels: ['UP', '1', '2', '5', '10', '15', '25', '30', '40'],
        angles: [0.0, 1.0, 2.0, 5.0, 10.0, 15.0, 25.0, 30.0, 40.0],
        maxAngle: 40,
      ),
      lightProfile: LightProfile(
        wingIndex: 0,
        logoIndex: 1,
        runwayLeftIndex: 2,
        runwayRightIndex: 3,
        taxiIndex: 4,
        wheelWellIndex: 5,
        landingIndices: [0, 1],
      ),
    ),
    AircraftIdentity(
      id: 'b737-max',
      manufacturer: 'Boeing',
      family: '737',
      model: '737 MAX',
      keywords: ['737 max', '737-8', '737-9', 'b737-8', 'b737-9', 'max'],
      flapDetents: 8,
      engineCount: 2,
      flapProfile: FlapProfile(
        labels: ['UP', '1', '2', '5', '10', '15', '25', '30', '40'],
        angles: [0.0, 1.0, 2.0, 5.0, 10.0, 15.0, 25.0, 30.0, 40.0],
        maxAngle: 40,
      ),
      lightProfile: LightProfile(
        wingIndex: 0,
        logoIndex: 1,
        runwayLeftIndex: 2,
        runwayRightIndex: 3,
        taxiIndex: 4,
        wheelWellIndex: 5,
      ),
    ),
    AircraftIdentity(
      id: 'b747-400',
      manufacturer: 'Boeing',
      family: '747',
      model: '747-400',
      keywords: ['747-400', 'b747-400', 'boeing 747-400'],
      engineCount: 4,
      flapDetents: 6,
      flapProfile: FlapProfile(
        labels: ['UP', '1', '5', '10', '20', '25', '30'],
        angles: [0.0, 1.0, 5.0, 10.0, 20.0, 25.0, 30.0],
        maxAngle: 30,
      ),
      lightProfile: LightProfile(
        runwayLeftIndex: 0,
        runwayRightIndex: 1,
        wingIndex: 2,
        logoIndex: 3,
        taxiIndex: 4,
        wheelWellIndex: 5,
      ),
    ),
    AircraftIdentity(
      id: 'b787-900',
      manufacturer: 'Boeing',
      family: '787',
      model: '787-900',
      keywords: ['787-900', 'b787-900', 'boeing 787-9', 'boeing 787'],
      engineCount: 2,
      flapProfile: FlapProfile(
        labels: ['UP', '1', '5', '10', '15', '17', '18', '20', '25', '30'],
        angles: [0.0, 1.0, 5.0, 10.0, 15.0, 17.0, 18.0, 20.0, 25.0, 30.0],
        maxAngle: 30,
      ),
      lightProfile: LightProfile(
        wingIndex: 0,
        runwayLeftIndex: 1,
        runwayRightIndex: 2,
        logoIndices: [3, 40, 64], // MagKnight 无法获取到Logo Light的映射
        taxiIndex: 4,
        wheelWellIndex: 5,
        landingIndices: [0, 1, 2],
      ),
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
          final normalizedKeyword = _normalize(keyword);
          if (normalizedKeyword.isEmpty) continue;
          if (normalizedTitle.contains(normalizedKeyword)) {
            score += 3;
          }
        }
      }
      final boeingFamilyHint = _extractBoeingFamilyHint(normalizedTitle);
      if (boeingFamilyHint != null && _isBoeing(entry)) {
        final familyDigits = _extractFamilyDigits(entry.family);
        if (familyDigits != null) {
          score += boeingFamilyHint == familyDigits ? 2 : -3;
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

  static bool _isBoeing(AircraftIdentity entry) {
    return entry.manufacturer.toLowerCase().contains('boeing');
  }

  static int? _extractFamilyDigits(String family) {
    final match = RegExp(r'\d+').firstMatch(family);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  static int? _extractBoeingFamilyHint(String normalizedTitle) {
    if (normalizedTitle.isEmpty) return null;
    final tokens = normalizedTitle.split(' ');
    for (final token in tokens) {
      if (token == '737' || token == '747' || token == '787') {
        return int.parse(token);
      }
      if (token.startsWith('b') && token.length >= 4) {
        final digits = token.substring(1);
        if (digits == '737' || digits == '747' || digits == '787') {
          return int.parse(digits);
        }
      }
    }
    return null;
  }
}
