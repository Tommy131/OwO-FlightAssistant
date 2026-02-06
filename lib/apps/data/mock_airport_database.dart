import '../models/airport_detail_data.dart';

/// 模拟机场数据库
/// 用于演示和作为API失败时的降级数据
class MockAirportDatabase {
  static const Map<String, Map<String, dynamic>> airports = {
    'ZSSS': {
      'iata': 'SHA',
      'name': '上海虹桥国际机场',
      'city': '上海',
      'country': '中国',
      'lat': 31.1979,
      'lon': 121.3364,
      'elevation': 10,
      'runways': [
        {
          'ident': '18L/36R',
          'lengthFt': 11155,
          'widthFt': 148,
          'surface': 'ASPH',
          'lighted': true,
          'closed': false,
          'le_ident': '18L',
          'he_ident': '36R',
        },
        {
          'ident': '18R/36L',
          'lengthFt': 10499,
          'widthFt': 197,
          'surface': 'ASPH',
          'lighted': true,
          'closed': false,
          'le_ident': '18R',
          'he_ident': '36L',
        },
      ],
      'frequencies': [
        {'type': 'ATIS', 'frequency': 127.850, 'description': 'ATIS'},
        {'type': 'TWR', 'frequency': 118.100, 'description': 'Tower'},
        {'type': 'GND', 'frequency': 121.600, 'description': 'Ground'},
        {'type': 'APP', 'frequency': 119.700, 'description': 'Approach'},
      ],
    },
    'ZBAA': {
      'iata': 'PEK',
      'name': '北京首都国际机场',
      'city': '北京',
      'country': '中国',
      'lat': 40.0799,
      'lon': 116.6031,
      'elevation': 116,
      'runways': [
        {
          'ident': '01/19',
          'lengthFt': 12467,
          'widthFt': 197,
          'surface': 'CONC',
          'lighted': true,
          'closed': false,
          'le_ident': '01',
          'he_ident': '19',
        },
        {
          'ident': '18L/36R',
          'lengthFt': 12467,
          'widthFt': 197,
          'surface': 'CONC',
          'lighted': true,
          'closed': false,
          'le_ident': '18L',
          'he_ident': '36R',
        },
        {
          'ident': '18R/36L',
          'lengthFt': 12467,
          'widthFt': 197,
          'surface': 'CONC',
          'lighted': true,
          'closed': false,
          'le_ident': '18R',
          'he_ident': '36L',
        },
      ],
      'frequencies': [
        {'type': 'ATIS', 'frequency': 127.600, 'description': 'ATIS'},
        {'type': 'TWR', 'frequency': 118.500, 'description': 'Tower'},
        {'type': 'GND', 'frequency': 121.750, 'description': 'Ground'},
        {'type': 'APP', 'frequency': 125.500, 'description': 'Approach'},
      ],
    },
    'ZSPD': {
      'iata': 'PVG',
      'name': '上海浦东国际机场',
      'city': '上海',
      'country': '中国',
      'lat': 31.1434,
      'lon': 121.8052,
      'elevation': 13,
      'runways': [
        {
          'ident': '16L/34R',
          'lengthFt': 13123,
          'widthFt': 197,
          'surface': 'CONC',
          'lighted': true,
          'closed': false,
          'le_ident': '16L',
          'he_ident': '34R',
        },
        {
          'ident': '16R/34L',
          'lengthFt': 13123,
          'widthFt': 197,
          'surface': 'CONC',
          'lighted': true,
          'closed': false,
          'le_ident': '16R',
          'he_ident': '34L',
        },
        {
          'ident': '17L/35R',
          'lengthFt': 12467,
          'widthFt': 197,
          'surface': 'CONC',
          'lighted': true,
          'closed': false,
          'le_ident': '17L',
          'he_ident': '35R',
        },
        {
          'ident': '17R/35L',
          'lengthFt': 12467,
          'widthFt': 197,
          'surface': 'CONC',
          'lighted': true,
          'closed': false,
          'le_ident': '17R',
          'he_ident': '35L',
        },
      ],
      'frequencies': [
        {'type': 'ATIS', 'frequency': 128.100, 'description': 'ATIS'},
        {'type': 'TWR', 'frequency': 118.750, 'description': 'Tower'},
        {'type': 'GND', 'frequency': 121.650, 'description': 'Ground'},
        {'type': 'APP', 'frequency': 120.400, 'description': 'Approach'},
      ],
    },
  };

  /// 将模拟数据转换为AirportDetailData对象
  static AirportDetailData? getAirportData(String icaoCode) {
    final data = airports[icaoCode];
    if (data == null) return null;

    return AirportDetailData(
      icaoCode: icaoCode,
      iataCode: data['iata'],
      name: data['name'],
      city: data['city'],
      country: data['country'],
      latitude: data['lat'],
      longitude: data['lon'],
      elevation: data['elevation'],
      runways: (data['runways'] as List<Map<String, dynamic>>)
          .map(
            (r) => RunwayInfo(
              ident: r['ident'],
              lengthFt: r['lengthFt'],
              widthFt: r['widthFt'],
              surface: r['surface'],
              lighted: r['lighted'],
              closed: r['closed'],
              le_ident: r['le_ident'],
              he_ident: r['he_ident'],
            ),
          )
          .toList(),
      frequencies: AirportFrequencies(
        all: (data['frequencies'] as List<Map<String, dynamic>>)
            .map(
              (f) => FrequencyInfo(
                type: f['type'],
                frequency: f['frequency'],
                description: f['description'],
              ),
            )
            .toList(),
      ),
      fetchedAt: DateTime.now(),
      dataSource: AirportDataSourceType.mockData,
    );
  }
}
