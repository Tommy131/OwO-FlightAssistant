/// 数据来源类型
enum AirportDataSourceType {
  aviationApi, // 在线API
  xplaneData, // X-Plane数据
  msfsData, // MSFS数据
  mockData, // 模拟数据
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
  final AirportFrequencies frequencies;
  final DateTime fetchedAt; // 数据获取时间
  final bool isCached; // 是否来自缓存
  final AirportDataSourceType dataSource; // 数据来源

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
    required this.frequencies,
    required this.fetchedAt,
    this.isCached = false,
    this.dataSource = AirportDataSourceType.aviationApi,
  });

  // 检查数据是否过期（超过30天）
  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(fetchedAt);
    return difference.inDays > 30;
  }

  // 获取数据年龄描述
  String get dataAge {
    final now = DateTime.now();
    final difference = now.difference(fetchedAt);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} 年前';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} 个月前';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} 天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} 小时前';
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
      case AirportDataSourceType.msfsData:
        return 'MSFS';
      case AirportDataSourceType.mockData:
        return '模拟数据';
    }
  }

  /// 是否为模拟数据
  bool get isMockData => dataSource == AirportDataSourceType.mockData;

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
      'frequencies': frequencies.toJson(),
      'fetchedAt': fetchedAt.toIso8601String(),
      'dataSource': dataSource.name,
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
      frequencies: AirportFrequencies.fromJson(
        json['frequencies'] as Map<String, dynamic>,
      ),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      dataSource: AirportDataSourceType.values.firstWhere(
        (s) => s.name == (json['dataSource'] ?? 'aviationApi'),
        orElse: () => AirportDataSourceType.aviationApi,
      ),
      isCached: true,
    );
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
  final String? le_ident; // Low end identifier (e.g., "17L")
  final String? he_ident; // High end identifier (e.g., "35R")

  RunwayInfo({
    required this.ident,
    this.lengthFt,
    this.widthFt,
    this.surface,
    this.lighted,
    this.closed,
    this.le_ident,
    this.he_ident,
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
      'le_ident': le_ident,
      'he_ident': he_ident,
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
      le_ident: json['le_ident'] as String?,
      he_ident: json['he_ident'] as String?,
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
