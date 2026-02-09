import '../services/weather_service.dart';

enum AirportDataSourceType {
  aviationApi, // 在线API
  xplaneData, // X-Plane数据
  lnmData, // Little Navmap数据
}

/// 机场详细信息数据模型
class AirportDetailData {
  final String icaoCode;
  final String? iataCode;
  final String name;
  final String? city;
  final String? country;
  final double latitude;
  final double longitude;
  final int? elevation; // in feet
  final List<RunwayInfo> runways;
  final List<NavaidInfo> navaids;
  final AirportFrequencies frequencies;
  final DateTime fetchedAt; // 数据获取时间
  final bool isCached; // 是否来自缓存
  final AirportDataSourceType dataSource; // 数据来源
  final MetarData? metar; // 气象报文
  final List<TaxiwayInfo> taxiways; // 滑行道几何数据
  final List<ParkingInfo> parkings; // 停机位数据

  AirportDetailData({
    required this.icaoCode,
    this.iataCode,
    required this.name,
    this.city,
    this.country,
    required this.latitude,
    required this.longitude,
    this.elevation,
    required this.runways,
    this.navaids = const [],
    required this.frequencies,
    required this.fetchedAt,
    this.isCached = false,
    this.dataSource = AirportDataSourceType.aviationApi,
    this.metar,
    this.taxiways = const [],
    this.parkings = const [],
  });

  AirportDetailData copyWith({
    String? icaoCode,
    String? iataCode,
    String? name,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    int? elevation,
    List<RunwayInfo>? runways,
    List<NavaidInfo>? navaids,
    AirportFrequencies? frequencies,
    DateTime? fetchedAt,
    bool? isCached,
    AirportDataSourceType? dataSource,
    MetarData? metar,
    List<TaxiwayInfo>? taxiways,
    List<ParkingInfo>? parkings,
  }) {
    return AirportDetailData(
      icaoCode: icaoCode ?? this.icaoCode,
      iataCode: iataCode ?? this.iataCode,
      name: name ?? this.name,
      city: city ?? this.city,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevation: elevation ?? this.elevation,
      runways: runways ?? this.runways,
      navaids: navaids ?? this.navaids,
      frequencies: frequencies ?? this.frequencies,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      isCached: isCached ?? this.isCached,
      dataSource: dataSource ?? this.dataSource,
      metar: metar ?? this.metar,
      taxiways: taxiways ?? this.taxiways,
      parkings: parkings ?? this.parkings,
    );
  }

  // 检查数据是否过期
  bool isExpired(int days) {
    final now = DateTime.now();
    final difference = now.difference(fetchedAt);
    return difference.inDays >= days;
  }

  // 获取数据年龄描述
  String get dataAge {
    final now = DateTime.now();
    final difference = now.difference(fetchedAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} 天前';
    } else if (difference.inHours > 0) {
      return '< ${difference.inHours + 1} 小时';
    } else if (difference.inMinutes > 5) {
      return '< 1 小时';
    } else {
      return '刚刚';
    }
  }

  /// 数据来源显示名称
  String get dataSourceDisplay {
    switch (dataSource) {
      case AirportDataSourceType.aviationApi:
        return '在线API';
      case AirportDataSourceType.xplaneData:
        return 'X-Plane';
      case AirportDataSourceType.lnmData:
        return 'Little Navmap';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'icaoCode': icaoCode,
      'iataCode': iataCode,
      'name': name,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'elevation': elevation,
      'runways': runways.map((r) => r.toJson()).toList(),
      'navaids': navaids.map((n) => n.toJson()).toList(),
      'frequencies': frequencies.toJson(),
      'fetchedAt': fetchedAt.toIso8601String(),
      'dataSource': dataSource.name,
      'metar': metar?.toJson(),
      'taxiways': taxiways.map((t) => t.toJson()).toList(),
      'parkings': parkings.map((p) => p.toJson()).toList(),
    };
  }

  factory AirportDetailData.fromJson(Map<String, dynamic> json) {
    return AirportDetailData(
      icaoCode: json['icaoCode'] as String,
      iataCode: json['iataCode'] as String?,
      name: json['name'] as String,
      city: json['city'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      elevation: json['elevation'] as int?,
      runways: (json['runways'] as List<dynamic>)
          .map((r) => RunwayInfo.fromJson(r as Map<String, dynamic>))
          .toList(),
      navaids:
          (json['navaids'] as List<dynamic>?)
              ?.map((n) => NavaidInfo.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
      frequencies: AirportFrequencies.fromJson(
        json['frequencies'] as Map<String, dynamic>,
      ),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      dataSource: AirportDataSourceType.values.firstWhere(
        (s) => s.name == (json['dataSource'] ?? 'aviationApi'),
        orElse: () => AirportDataSourceType.aviationApi,
      ),
      isCached: true,
      metar: json['metar'] != null ? MetarData.fromJson(json['metar']) : null,
      taxiways:
          (json['taxiways'] as List<dynamic>?)
              ?.map((t) => TaxiwayInfo.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      parkings:
          (json['parkings'] as List<dynamic>?)
              ?.map((p) => ParkingInfo.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// 检查两份数据是否存在显著差异（用于提示用户更新）
  bool hasSignificantDifference(AirportDetailData other) {
    if (icaoCode != other.icaoCode) return true;

    // 坐标差异大于 0.01 度 (约 1km)
    if ((latitude - other.latitude).abs() > 0.01 ||
        (longitude - other.longitude).abs() > 0.01) {
      return true;
    }

    // 跑道数量差异
    if (runways.length != other.runways.length) return true;

    // 名称差异显著且当前不为空
    if (name != other.name &&
        name != 'Unknown Airport' &&
        !name.contains('未知机场')) {
      return true;
    }

    return false;
  }

  /// 使用新数据“补充”当前数据（仅更新 null 或 Unknown 字段）
  AirportDetailData complementWith(AirportDetailData other) {
    return AirportDetailData(
      icaoCode: icaoCode,
      iataCode: (iataCode == null || iataCode!.isEmpty)
          ? other.iataCode
          : iataCode,
      name: (name == 'Unknown Airport' || name.contains('未知机场'))
          ? other.name
          : name,
      city: (city == null || city!.isEmpty) ? other.city : city,
      country: (country == null || country!.isEmpty) ? other.country : country,
      latitude: latitude != 0 ? latitude : other.latitude,
      longitude: longitude != 0 ? longitude : other.longitude,
      elevation: elevation ?? other.elevation,
      runways: _mergeRunways(runways, other.runways),
      navaids: _mergeNavaids(navaids, other.navaids),
      frequencies: frequencies.complementWith(other.frequencies),
      fetchedAt: DateTime.now(),
      dataSource: other.dataSource,
      isCached: false,
      metar: other.metar ?? metar,
    );
  }

  List<RunwayInfo> _mergeRunways(
    List<RunwayInfo> current,
    List<RunwayInfo> incoming,
  ) {
    final result = <RunwayInfo>[...current];
    for (final inc in incoming) {
      final index = result.indexWhere((r) => r.ident == inc.ident);
      if (index != -1) {
        result[index] = result[index].complementWith(inc);
      } else {
        result.add(inc);
      }
    }
    return result;
  }

  List<NavaidInfo> _mergeNavaids(
    List<NavaidInfo> current,
    List<NavaidInfo> incoming,
  ) {
    // 主要是合并，根据标识符去重
    final map = {for (var n in current) n.ident: n};
    for (final inc in incoming) {
      if (!map.containsKey(inc.ident)) {
        map[inc.ident] = inc;
      }
    }
    return map.values.toList();
  }
}

/// 跑道信息
class RunwayInfo {
  final String ident; // e.g., "17L/35R"
  final int? lengthFt; // 长度（英尺）
  final int? widthFt; // 宽度（英尺）
  final String? surface; // 跑道表面类型
  final bool? lighted; // 是否有灯光
  final bool? closed; // 是否关闭
  final String? leIdent; // Low end identifier (e.g., "17L")
  final String? heIdent; // High end identifier (e.g., "35R")
  final IlsInfo? leIls; // Low end ILS information
  final IlsInfo? heIls; // High end ILS information
  final double? leLat; // 低端纬度
  final double? leLon; // 低端经度
  final double? heLat; // 高端纬度
  final double? heLon; // 高端经度

  RunwayInfo({
    required this.ident,
    this.lengthFt,
    this.widthFt,
    this.surface,
    this.lighted,
    this.closed,
    this.leIdent,
    this.heIdent,
    this.leIls,
    this.heIls,
    this.leLat,
    this.leLon,
    this.heLat,
    this.heLon,
  });

  String get lengthMeters =>
      lengthFt != null ? '${(lengthFt! * 0.3048).toStringAsFixed(0)}m' : 'N/A';

  String get surfaceDisplay {
    if (surface == null) return 'Unknown';
    switch (surface!.toUpperCase()) {
      case 'ASP':
      case 'ASPH':
        return '沥青';
      case 'CON':
      case 'CONC':
        return '混凝土';
      case 'GRS':
      case 'GRASS':
        return '草地';
      case 'DIRT':
        return '土质';
      case 'GRAVEL':
        return '碎石';
      case 'WATER':
        return '水面';
      default:
        return surface!;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'ident': ident,
      'lengthFt': lengthFt,
      'widthFt': widthFt,
      'surface': surface,
      'lighted': lighted,
      'closed': closed,
      'le_ident': leIdent,
      'he_ident': heIdent,
      'le_ils': leIls?.toJson(),
      'he_ils': heIls?.toJson(),
    };
  }

  factory RunwayInfo.fromJson(Map<String, dynamic> json) {
    return RunwayInfo(
      ident: json['ident'] as String,
      lengthFt: json['lengthFt'] as int?,
      widthFt: json['widthFt'] as int?,
      surface: json['surface'] as String?,
      lighted: json['lighted'] as bool?,
      closed: json['closed'] as bool?,
      leIdent: (json['le_ident'] ?? json['leIdent']) as String?,
      heIdent: (json['he_ident'] ?? json['heIdent']) as String?,
      leIls: (json['le_ils'] ?? json['leIls']) != null
          ? IlsInfo.fromJson(
              (json['le_ils'] ?? json['leIls']) as Map<String, dynamic>,
            )
          : null,
      heIls: (json['he_ils'] ?? json['heIls']) != null
          ? IlsInfo.fromJson(
              (json['he_ils'] ?? json['heIls']) as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// 补充跑道信息
  RunwayInfo complementWith(RunwayInfo other) {
    return RunwayInfo(
      ident: ident,
      lengthFt: lengthFt ?? other.lengthFt,
      widthFt: widthFt ?? other.widthFt,
      surface: (surface == null || surface == 'Unknown')
          ? other.surface
          : surface,
      lighted: lighted ?? other.lighted,
      closed: closed ?? other.closed,
      leIdent: leIdent ?? other.leIdent,
      heIdent: heIdent ?? other.heIdent,
      leIls: leIls ?? other.leIls,
      heIls: heIls ?? other.heIls,
      leLat: leLat ?? other.leLat,
      leLon: leLon ?? other.leLon,
      heLat: heLat ?? other.heLat,
      heLon: heLon ?? other.heLon,
    );
  }
}

/// ILS 信息
class IlsInfo {
  final double freq; // 频率 (MHz)
  final int course; // 航向 (Degrees)

  IlsInfo({required this.freq, required this.course});

  Map<String, dynamic> toJson() {
    return {'freq': freq, 'course': course};
  }

  factory IlsInfo.fromJson(Map<String, dynamic> json) {
    return IlsInfo(
      freq: (json['freq'] as num).toDouble(),
      course: (json['course'] as num).toInt(),
    );
  }
}

/// 助航设备 (Navaid) 信息
class NavaidInfo {
  final String ident;
  final String name;
  final String type; // e.g., "VOR-DME", "NDB"
  final double frequency; // in kHz or MHz
  final double latitude;
  final double longitude;
  final int? elevation;
  final String? channel; // for DME

  NavaidInfo({
    required this.ident,
    required this.name,
    required this.type,
    required this.frequency,
    required this.latitude,
    required this.longitude,
    this.elevation,
    this.channel,
  });

  Map<String, dynamic> toJson() {
    return {
      'ident': ident,
      'name': name,
      'type': type,
      'frequency': frequency,
      'latitude': latitude,
      'longitude': longitude,
      'elevation': elevation,
      'channel': channel,
    };
  }

  factory NavaidInfo.fromJson(Map<String, dynamic> json) {
    return NavaidInfo(
      ident: json['ident'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      frequency: (json['frequency'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      elevation: json['elevation'] as int?,
      channel: json['channel'] as String?,
    );
  }
}

/// 机场频率信息
class AirportFrequencies {
  final List<FrequencyInfo> all;

  AirportFrequencies({required this.all});

  List<FrequencyInfo> get tower =>
      all.where((f) => f.type.toLowerCase().contains('twr')).toList();

  List<FrequencyInfo> get ground =>
      all.where((f) => f.type.toLowerCase().contains('gnd')).toList();

  List<FrequencyInfo> get approach =>
      all.where((f) => f.type.toLowerCase().contains('app')).toList();

  List<FrequencyInfo> get departure =>
      all.where((f) => f.type.toLowerCase().contains('dep')).toList();

  List<FrequencyInfo> get atis =>
      all.where((f) => f.type.toLowerCase().contains('atis')).toList();

  Map<String, dynamic> toJson() {
    return {'all': all.map((f) => f.toJson()).toList()};
  }

  factory AirportFrequencies.fromJson(Map<String, dynamic> json) {
    return AirportFrequencies(
      all: (json['all'] as List<dynamic>)
          .map((f) => FrequencyInfo.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 补充频率信息 (按照类型和频率去重合并)
  AirportFrequencies complementWith(AirportFrequencies other) {
    final result = <FrequencyInfo>[...all];
    for (final inc in other.all) {
      final exists = result.any(
        (f) =>
            f.type == inc.type && (f.frequency - inc.frequency).abs() < 0.001,
      );
      if (!exists) {
        result.add(inc);
      }
    }
    return AirportFrequencies(all: result);
  }
}

/// 频率信息
class FrequencyInfo {
  final String type; // e.g., "TWR", "GND", "APP", "ATIS"
  final double frequency; // in MHz
  final String? description;

  FrequencyInfo({
    required this.type,
    required this.frequency,
    this.description,
  });

  String get displayFrequency => frequency.toStringAsFixed(3);

  String get typeDisplay {
    switch (type.toUpperCase()) {
      case 'TWR':
        return '塔台';
      case 'GND':
        return '地面';
      case 'APP':
        return '进近';
      case 'DEP':
        return '离场';
      case 'ATIS':
        return 'ATIS';
      case 'CTAF':
        return 'CTAF';
      case 'UNICOM':
        return 'UNICOM';
      default:
        return type;
    }
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'frequency': frequency, 'description': description};
  }

  factory FrequencyInfo.fromJson(Map<String, dynamic> json) {
    return FrequencyInfo(
      type: json['type'] as String,
      frequency: (json['frequency'] as num).toDouble(),
      description: json['description'] as String?,
    );
  }
}

/// 滑行道几何信息
class TaxiwayInfo {
  final String? name;
  final List<Coord> points;

  TaxiwayInfo({this.name, required this.points});

  Map<String, dynamic> toJson() => {
    'name': name,
    'points': points.map((p) => p.toJson()).toList(),
  };

  factory TaxiwayInfo.fromJson(Map<String, dynamic> json) => TaxiwayInfo(
    name: json['name'] as String?,
    points: (json['points'] as List<dynamic>)
        .map((p) => Coord.fromJson(p as Map<String, dynamic>))
        .toList(),
  );
}

/// 停机位信息
class ParkingInfo {
  final String name;
  final double latitude;
  final double longitude;
  final double heading; // 停机位朝向

  ParkingInfo({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.heading,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'heading': heading,
  };

  factory ParkingInfo.fromJson(Map<String, dynamic> json) => ParkingInfo(
    name: json['name'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    heading: (json['heading'] as num).toDouble(),
  );
}

/// 通用坐标
class Coord {
  final double latitude;
  final double longitude;

  Coord(this.latitude, this.longitude);

  Map<String, dynamic> toJson() => {'lat': latitude, 'lon': longitude};

  factory Coord.fromJson(Map<String, dynamic> json) =>
      Coord((json['lat'] as num).toDouble(), (json['lon'] as num).toDouble());
}
