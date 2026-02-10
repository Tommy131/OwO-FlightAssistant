import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import '../models/airport_detail_data.dart';
import '../../core/utils/logger.dart';

/// Little Navmap 数据库解析器
class LNMDatabaseParser {
  /// 从 Little Navmap 数据库中解析机场信息
  static Future<AirportDetailData?> parseAirport(
    File dbFile,
    String icao,
  ) async {
    Database? db;
    try {
      if (!await dbFile.exists()) {
        AppLogger.error(
          'Little Navmap database file not found: ${dbFile.path}',
        );
        return null;
      }

      // 打开 SQLite 数据库
      db = sqlite3.open(dbFile.path);

      // 调试：打印所有列名
      final airportColumns = _getTableColumns(db, 'airport');

      final latCol = airportColumns.contains('latitude')
          ? 'latitude'
          : (airportColumns.contains('lat')
                ? 'lat'
                : (airportColumns.contains('laty') ? 'laty' : null));
      final lonCol = airportColumns.contains('longitude')
          ? 'longitude'
          : (airportColumns.contains('lon')
                ? 'lon'
                : (airportColumns.contains('lonx') ? 'lonx' : null));

      if (latCol == null || lonCol == null) {
        AppLogger.error(
          'Could not find latitude/longitude columns in airport table. Available: ${airportColumns.join(', ')}',
        );
        return null;
      }

      // 1. 查询机场基本信息
      final airportResults = db.select(
        'SELECT airport_id, ident, name, city, country, $latCol, $lonCol, altitude '
        'FROM airport WHERE ident = ? LIMIT 1',
        [icao],
      );

      if (airportResults.isEmpty) {
        AppLogger.debug('Airport $icao not found in Little Navmap database');
        return null;
      }

      final airportRow = airportResults.first;
      final int airportId = airportRow['airport_id'] as int;

      // 检查跑道表字段
      final runwayColumns = _getTableColumns(db, 'runway');

      // 发现：在最新的 LNM 数据库中，runway 表不直接包含 ident，而是通过 primary_end_id 关联到 runway_end 表
      final hasRunwayEndTable = db
          .select(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='runway_end'",
          )
          .isNotEmpty;

      final rLatCol = runwayColumns.contains('latitude')
          ? 'latitude'
          : (runwayColumns.contains('lat')
                ? 'lat'
                : (runwayColumns.contains('laty') ? 'laty' : null));
      final rLonCol = runwayColumns.contains('longitude')
          ? 'longitude'
          : (runwayColumns.contains('lon')
                ? 'lon'
                : (runwayColumns.contains('lonx') ? 'lonx' : null));

      // 2. 查询跑道信息
      final List<Map<String, dynamic>> runwayRows;
      if (hasRunwayEndTable) {
        final reColumns = _getTableColumns(db, 'runway_end');
        final reLatCol = reColumns.contains('latitude')
            ? 'latitude'
            : (reColumns.contains('lat')
                  ? 'lat'
                  : (reColumns.contains('laty')
                        ? 'laty'
                        : (reColumns.contains('pos_lat') ? 'pos_lat' : null)));
        final reLonCol = reColumns.contains('longitude')
            ? 'longitude'
            : (reColumns.contains('lon')
                  ? 'lon'
                  : (reColumns.contains('lonx')
                        ? 'lonx'
                        : (reColumns.contains('pos_lon') ? 'pos_lon' : null)));

        // 检查是否有 ils 表
        final hasIlsTable = db
            .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='ils'",
            )
            .isNotEmpty;

        final String ilsJoin;
        final String ilsSelect;
        if (hasIlsTable && reColumns.contains('ils_id')) {
          ilsJoin = '''
            LEFT JOIN ils i1 ON re1.ils_id = i1.ils_id
            LEFT JOIN ils i2 ON re2.ils_id = i2.ils_id
          ''';
          ilsSelect = '''
            , i1.ident as le_ils_ident, i1.freq as le_ils_freq, i1.course as le_ils_course, i1.gs_angle as le_ils_gs, i1.latitude as le_ils_lat, i1.longitude as le_ils_lon
            , i2.ident as he_ils_ident, i2.freq as he_ils_freq, i2.course as he_ils_course, i2.gs_angle as he_ils_gs, i2.latitude as he_ils_lat, i2.longitude as he_ils_lon
          ''';
        } else {
          ilsJoin = '';
          ilsSelect = '';
        }

        if (reLatCol == null || reLonCol == null) {
          AppLogger.error(
            'Could not find lat/lon in runway_end. Available: ${reColumns.join(', ')}',
          );
        }

        // 如果有 runway_end 表，获取两端的详细坐标
        final sql =
            '''
          SELECT
            re1.name || '/' || re2.name as runway_ident,
            r.length, r.width, r.surface,
            re1.name as le_ident,
            ${reLatCol != null ? "re1.$reLatCol" : "NULL"} as le_lat,
            ${reLonCol != null ? "re1.$reLonCol" : "NULL"} as le_lon,
            re2.name as he_ident,
            ${reLatCol != null ? "re2.$reLatCol" : "NULL"} as he_lat,
            ${reLonCol != null ? "re2.$reLonCol" : "NULL"} as he_lon
            $ilsSelect
          FROM runway r
          JOIN runway_end re1 ON r.primary_end_id = re1.runway_end_id
          JOIN runway_end re2 ON r.secondary_end_id = re2.runway_end_id
          $ilsJoin
          WHERE r.airport_id = ?
        ''';
        runwayRows = db.select(sql, [airportId]).map((row) => row).toList();
      } else {
        // 回退到之前的逻辑
        final rIdentCol = runwayColumns.contains('ident')
            ? 'ident'
            : (runwayColumns.contains('name') ? 'name' : null);

        if (rIdentCol == null) {
          AppLogger.error(
            'Could not find identity column in runway table and no runway_end table found.',
          );
          return null;
        }

        final sql =
            'SELECT $rIdentCol as runway_ident, length, width, surface, '
            '${rLatCol ?? "NULL"} as le_lat, ${rLonCol ?? "NULL"} as le_lon '
            'FROM runway WHERE airport_id = ?';
        runwayRows = db.select(sql, [airportId]).map((row) => row).toList();
      }

      final runways = <RunwayInfo>[];
      for (final row in runwayRows) {
        // 解析 ILS 信息
        IlsInfo? leIls;
        if (row['le_ils_freq'] != null) {
          final double rawFreq = (row['le_ils_freq'] as num).toDouble();
          leIls = IlsInfo(
            ident: row['le_ils_ident'] as String?,
            // LNM 频率通常以 kHz 存储（如 110500 代表 110.50），或者是 10Hz 为单位（如 11050）
            // 根据常规做法，如果大于 10000 则是 kHz，否则可能是已经处理过的 MHz 或其他单位
            freq: rawFreq > 1000 ? rawFreq / 1000.0 : rawFreq,
            course: (row['le_ils_course'] as num?)?.toInt() ?? 0,
            gsAngle: (row['le_ils_gs'] as num?)?.toDouble(),
            lat: (row['le_ils_lat'] as num?)?.toDouble(),
            lon: (row['le_ils_lon'] as num?)?.toDouble(),
          );
        }

        IlsInfo? heIls;
        if (row['he_ils_freq'] != null) {
          final double rawFreq = (row['he_ils_freq'] as num).toDouble();
          heIls = IlsInfo(
            ident: row['he_ils_ident'] as String?,
            freq: rawFreq > 1000 ? rawFreq / 1000.0 : rawFreq,
            course: (row['he_ils_course'] as num?)?.toInt() ?? 0,
            gsAngle: (row['he_ils_gs'] as num?)?.toDouble(),
            lat: (row['he_ils_lat'] as num?)?.toDouble(),
            lon: (row['he_ils_lon'] as num?)?.toDouble(),
          );
        }

        runways.add(
          RunwayInfo(
            ident: row['runway_ident'] as String,
            lengthFt: (row['length'] as num?)?.toInt(),
            widthFt: (row['width'] as num?)?.toInt(),
            surface: row['surface'] as String?,
            leIdent: row['le_ident'] as String?,
            leLat: (row['le_lat'] as num?)?.toDouble(),
            leLon: (row['le_lon'] as num?)?.toDouble(),
            heIdent: row['he_ident'] as String?,
            heLat: (row['he_lat'] as num?)?.toDouble(),
            heLon: (row['he_lon'] as num?)?.toDouble(),
            leIls: leIls,
            heIls: heIls,
          ),
        );
      }

      // 3. 查询频率信息
      final comColumns = _getTableColumns(db, 'com');

      final freqCol = comColumns.contains('freq')
          ? 'freq'
          : (comColumns.contains('frequency')
                ? 'frequency'
                : (comColumns.contains('mhz') ? 'mhz' : null));

      final comNameCol = comColumns.contains('name')
          ? 'name'
          : (comColumns.contains('description') ? 'description' : null);

      final frequencies = <FrequencyInfo>[];
      if (freqCol != null) {
        final freqResults = db.select(
          'SELECT type, $freqCol ${(comNameCol != null) ? ", $comNameCol" : ""} FROM com WHERE airport_id = ?',
          [airportId],
        );

        for (final row in freqResults) {
          final rawFreq = row[freqCol] as num;
          // 处理频率单位：LNM 数据库根据来源不同，可能以 Hz, kHz 或 MHz 存储
          double frequencyMhz = rawFreq.toDouble();
          if (frequencyMhz >= 1000000) {
            frequencyMhz /= 1000000.0; // Hz -> MHz
          } else if (frequencyMhz >= 1000) {
            frequencyMhz /= 1000.0; // kHz -> MHz
          }

          frequencies.add(
            FrequencyInfo(
              type: row['type'] as String? ?? 'UNK',
              frequency: frequencyMhz,
              description: comNameCol != null
                  ? row[comNameCol] as String?
                  : null,
            ),
          );
        }
      }

      // 4. 查询机场附近的导航台 (50海里范围内)
      final navaids = <NavaidInfo>[];
      try {
        final navColumns = _getTableColumns(db, 'navaid');
        if (navColumns.isNotEmpty) {
          final nLatCol = navColumns.contains('latitude')
              ? 'latitude'
              : (navColumns.contains('lat') ? 'lat' : 'laty');
          final nLonCol = navColumns.contains('longitude')
              ? 'longitude'
              : (navColumns.contains('lon') ? 'lon' : 'lonx');
          final nFreqCol = navColumns.contains('freq')
              ? 'freq'
              : (navColumns.contains('frequency') ? 'frequency' : 'mhz');

          final lat = (airportRow[latCol] as num).toDouble();
          final lon = (airportRow[lonCol] as num).toDouble();
          const range = 0.8;

          final navResults = db.select(
            'SELECT ident, name, type, $nFreqCol, $nLatCol, $nLonCol, altitude, channel '
            'FROM navaid '
            'WHERE $nLatCol BETWEEN ? AND ? AND $nLonCol BETWEEN ? AND ?',
            [lat - range, lat + range, lon - range, lon + range],
          );

          for (final row in navResults) {
            final rawFreq = row[nFreqCol] as num;
            final type = (row['type'] as String? ?? 'UNK').toUpperCase();

            double frequency = rawFreq.toDouble();
            if (frequency >= 1000000) {
              frequency /= 1000000.0;
            } else if (frequency >= 1000) {
              frequency /= 1000.0;
            }

            // NDB 特殊处理
            if (type.contains('NDB') && frequency < 2.0) {
              frequency *= 1000.0;
            }

            navaids.add(
              NavaidInfo(
                ident: row['ident'] as String? ?? 'N/A',
                name: row['name'] as String? ?? 'N/A',
                type: type,
                frequency: frequency,
                latitude: (row[nLatCol] as num).toDouble(),
                longitude: (row[nLonCol] as num).toDouble(),
                elevation: (row['altitude'] as num?)?.toInt(),
                channel: row['channel'] as String?,
              ),
            );
          }
        }
      } catch (e) {
        AppLogger.error('Error parsing navaids from LNM: $e');
      }

      // 5. 查询停机位信息 (Parking)
      final parkings = <ParkingInfo>[];
      try {
        final parkingColumns = _getTableColumns(db, 'parking');
        if (parkingColumns.isNotEmpty) {
          final pLatCol = parkingColumns.contains('latitude')
              ? 'latitude'
              : (parkingColumns.contains('lat') ? 'lat' : 'laty');
          final pLonCol = parkingColumns.contains('longitude')
              ? 'longitude'
              : (parkingColumns.contains('lon') ? 'lon' : 'lonx');

          final parkingResults = db.select(
            'SELECT name, $pLatCol, $pLonCol, heading FROM parking WHERE airport_id = ?',
            [airportId],
          );

          for (final row in parkingResults) {
            parkings.add(
              ParkingInfo(
                name: row['name'] as String? ?? 'N/A',
                latitude: (row[pLatCol] as num).toDouble(),
                longitude: (row[pLonCol] as num).toDouble(),
                heading: (row['heading'] as num?)?.toDouble() ?? 0.0,
              ),
            );
          }
        }
      } catch (e) {
        AppLogger.error('Error parsing parkings from LNM: $e');
      }

      // 6. 查询滑行道信息 (Taxiway)
      final taxiways = <TaxiwayInfo>[];
      try {
        final taxiColumns = _getTableColumns(db, 'taxiway');
        final hasTaxiwayTable = taxiColumns.isNotEmpty;
        final hasTaxiwayPointTable = db
            .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='taxiway_point'",
            )
            .isNotEmpty;
        final hasTaxiwayNodeTable = db
            .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='taxiway_node'",
            )
            .isNotEmpty;
        final hasTaxiwayPathTable = db
            .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='taxiway_path'",
            )
            .isNotEmpty;
        final hasTaxiwayPathPointTable = db
            .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='taxiway_path_point'",
            )
            .isNotEmpty;

        bool parsed = false;
        if (hasTaxiwayTable) {
          final taxiIdCol = taxiColumns.contains('taxiway_id')
              ? 'taxiway_id'
              : (taxiColumns.contains('id') ? 'id' : null);
          final taxiNameCol = taxiColumns.contains('name')
              ? 'name'
              : (taxiColumns.contains('ident') ? 'ident' : null);
          final taxiAirportIdCol = taxiColumns.contains('airport_id')
              ? 'airport_id'
              : (taxiColumns.contains('ap_id') ? 'ap_id' : null);

          final pointTable = hasTaxiwayPointTable
              ? 'taxiway_point'
              : 'taxiway_node';
          if ((hasTaxiwayPointTable || hasTaxiwayNodeTable) &&
              taxiIdCol != null &&
              taxiAirportIdCol != null) {
            final pointColumns = _getTableColumns(db, pointTable);
            final pLatCol = pointColumns.contains('latitude')
                ? 'latitude'
                : (pointColumns.contains('lat')
                      ? 'lat'
                      : (pointColumns.contains('laty') ? 'laty' : null));
            final pLonCol = pointColumns.contains('longitude')
                ? 'longitude'
                : (pointColumns.contains('lon')
                      ? 'lon'
                      : (pointColumns.contains('lonx') ? 'lonx' : null));
            final pOrderCol = pointColumns.contains('sequence')
                ? 'sequence'
                : (pointColumns.contains('seq')
                      ? 'seq'
                      : (pointColumns.contains('idx')
                            ? 'idx'
                            : (pointColumns.contains('position')
                                  ? 'position'
                                  : null)));
            final pTaxiIdCol = pointColumns.contains('taxiway_id')
                ? 'taxiway_id'
                : (pointColumns.contains('taxiway')
                      ? 'taxiway'
                      : (pointColumns.contains('taxiway_fk')
                            ? 'taxiway_fk'
                            : null));

            if (pLatCol != null && pLonCol != null && pTaxiIdCol != null) {
              final selectName = taxiNameCol != null
                  ? ', t.$taxiNameCol as name'
                  : '';
              final selectOrder = pOrderCol != null
                  ? ', p.$pOrderCol as ord'
                  : '';
              final orderBy = pOrderCol != null
                  ? 'ORDER BY t.$taxiIdCol, p.$pOrderCol'
                  : 'ORDER BY t.$taxiIdCol';
              final sql =
                  'SELECT t.$taxiIdCol as taxi_id$selectName, p.$pLatCol as lat, p.$pLonCol as lon$selectOrder '
                  'FROM taxiway t JOIN $pointTable p ON t.$taxiIdCol = p.$pTaxiIdCol '
                  'WHERE t.$taxiAirportIdCol = ? $orderBy';

              final rows = db.select(sql, [airportId]);
              final map = <int, List<Coord>>{};
              final names = <int, String?>{};
              for (final row in rows) {
                final id = row['taxi_id'] as int;
                final lat = (row['lat'] as num).toDouble();
                final lon = (row['lon'] as num).toDouble();

                final points = map.putIfAbsent(id, () => []);

                // 修复：如果新点与上一个点距离过远（超过500米），则认为是一个新的段，避免连成“乱麻”
                if (points.isNotEmpty) {
                  final last = points.last;
                  // 简单的经纬度距离估算 (1度约111km)
                  final distSq =
                      (last.latitude - lat) * (last.latitude - lat) +
                      (last.longitude - lon) * (last.longitude - lon);
                  if (distSq > 0.00002) {
                    // 约 500m
                    // 如果太远，我们把之前的存入结果，并开启新的段
                    if (points.length > 1) {
                      taxiways.add(
                        TaxiwayInfo(name: names[id], points: List.from(points)),
                      );
                    }
                    points.clear();
                  }
                }

                points.add(Coord(lat, lon));
                if (taxiNameCol != null && !names.containsKey(id)) {
                  names[id] = row['name'] as String?;
                }
              }

              for (final entry in map.entries) {
                if (entry.value.length > 1) {
                  taxiways.add(
                    TaxiwayInfo(name: names[entry.key], points: entry.value),
                  );
                }
              }
              parsed = taxiways.isNotEmpty;
            }
          }
        }

        if (!parsed && hasTaxiwayPathTable && hasTaxiwayPathPointTable) {
          final pathColumns = _getTableColumns(db, 'taxiway_path');
          final pathIdCol = pathColumns.contains('taxiway_path_id')
              ? 'taxiway_path_id'
              : (pathColumns.contains('path_id') ? 'path_id' : null);
          final pathAirportIdCol = pathColumns.contains('airport_id')
              ? 'airport_id'
              : (pathColumns.contains('ap_id') ? 'ap_id' : null);
          final pathNameCol = pathColumns.contains('name')
              ? 'name'
              : (pathColumns.contains('ident') ? 'ident' : null);

          if (pathIdCol != null && pathAirportIdCol != null) {
            final pathPointColumns = _getTableColumns(db, 'taxiway_path_point');
            final pLatCol = pathPointColumns.contains('latitude')
                ? 'latitude'
                : (pathPointColumns.contains('lat')
                      ? 'lat'
                      : (pathPointColumns.contains('laty') ? 'laty' : null));
            final pLonCol = pathPointColumns.contains('longitude')
                ? 'longitude'
                : (pathPointColumns.contains('lon')
                      ? 'lon'
                      : (pathPointColumns.contains('lonx') ? 'lonx' : null));
            final pOrderCol = pathPointColumns.contains('sequence')
                ? 'sequence'
                : (pathPointColumns.contains('seq')
                      ? 'seq'
                      : (pathPointColumns.contains('idx')
                            ? 'idx'
                            : (pathPointColumns.contains('position')
                                  ? 'position'
                                  : null)));
            final pPathIdCol = pathPointColumns.contains('taxiway_path_id')
                ? 'taxiway_path_id'
                : (pathPointColumns.contains('path_id')
                      ? 'path_id'
                      : (pathPointColumns.contains('taxiway_path')
                            ? 'taxiway_path'
                            : null));

            if (pLatCol != null && pLonCol != null && pPathIdCol != null) {
              final selectName = pathNameCol != null
                  ? ', t.$pathNameCol as name'
                  : '';
              final selectOrder = pOrderCol != null
                  ? ', p.$pOrderCol as ord'
                  : '';
              final orderBy = pOrderCol != null
                  ? 'ORDER BY t.$pathIdCol, p.$pOrderCol'
                  : 'ORDER BY t.$pathIdCol';
              final sql =
                  'SELECT t.$pathIdCol as path_id$selectName, p.$pLatCol as lat, p.$pLonCol as lon$selectOrder '
                  'FROM taxiway_path t JOIN taxiway_path_point p ON t.$pathIdCol = p.$pPathIdCol '
                  'WHERE t.$pathAirportIdCol = ? $orderBy';

              final rows = db.select(sql, [airportId]);
              final map = <int, List<Coord>>{};
              final names = <int, String?>{};
              for (final row in rows) {
                final id = row['path_id'] as int;
                final lat = (row['lat'] as num).toDouble();
                final lon = (row['lon'] as num).toDouble();

                final points = map.putIfAbsent(id, () => []);

                // 修复：如果新点与上一个点距离过远（超过500米），则认为是一个新的段，避免连成“乱麻”
                if (points.isNotEmpty) {
                  final last = points.last;
                  final distSq =
                      (last.latitude - lat) * (last.latitude - lat) +
                      (last.longitude - lon) * (last.longitude - lon);
                  if (distSq > 0.00002) {
                    if (points.length > 1) {
                      taxiways.add(
                        TaxiwayInfo(name: names[id], points: List.from(points)),
                      );
                    }
                    points.clear();
                  }
                }

                points.add(Coord(lat, lon));
                if (pathNameCol != null && !names.containsKey(id)) {
                  names[id] = row['name'] as String?;
                }
              }

              for (final entry in map.entries) {
                if (entry.value.length > 1) {
                  taxiways.add(
                    TaxiwayInfo(name: names[entry.key], points: entry.value),
                  );
                }
              }
              parsed = taxiways.isNotEmpty;
            }
          }
        }

        if (!parsed) {
          final hasTaxiPathTable = db
              .select(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='taxi_path'",
              )
              .isNotEmpty;
          if (hasTaxiPathTable) {
            final pathColumns = _getTableColumns(db, 'taxi_path');
            final pAirportIdCol = pathColumns.contains('airport_id')
                ? 'airport_id'
                : (pathColumns.contains('ap_id') ? 'ap_id' : null);
            final pNameCol = pathColumns.contains('name')
                ? 'name'
                : (pathColumns.contains('ident') ? 'ident' : null);
            final startLatCol = pathColumns.contains('start_laty')
                ? 'start_laty'
                : (pathColumns.contains('start_lat')
                      ? 'start_lat'
                      : (pathColumns.contains('start_latitude')
                            ? 'start_latitude'
                            : null));
            final startLonCol = pathColumns.contains('start_lonx')
                ? 'start_lonx'
                : (pathColumns.contains('start_lon')
                      ? 'start_lon'
                      : (pathColumns.contains('start_longitude')
                            ? 'start_longitude'
                            : null));
            final endLatCol = pathColumns.contains('end_laty')
                ? 'end_laty'
                : (pathColumns.contains('end_lat')
                      ? 'end_lat'
                      : (pathColumns.contains('end_latitude')
                            ? 'end_latitude'
                            : null));
            final endLonCol = pathColumns.contains('end_lonx')
                ? 'end_lonx'
                : (pathColumns.contains('end_lon')
                      ? 'end_lon'
                      : (pathColumns.contains('end_longitude')
                            ? 'end_longitude'
                            : null));

            if (pAirportIdCol != null &&
                startLatCol != null &&
                startLonCol != null &&
                endLatCol != null &&
                endLonCol != null) {
              final selectName = pNameCol != null ? ', $pNameCol as name' : '';
              final sql =
                  'SELECT $startLatCol as slat, $startLonCol as slon, $endLatCol as elat, $endLonCol as elon$selectName '
                  'FROM taxi_path WHERE $pAirportIdCol = ?';
              final rows = db.select(sql, [airportId]);
              for (final row in rows) {
                final slat = (row['slat'] as num?)?.toDouble();
                final slon = (row['slon'] as num?)?.toDouble();
                final elat = (row['elat'] as num?)?.toDouble();
                final elon = (row['elon'] as num?)?.toDouble();
                if (slat != null &&
                    slon != null &&
                    elat != null &&
                    elon != null) {
                  taxiways.add(
                    TaxiwayInfo(
                      name: pNameCol != null ? row['name'] as String? : null,
                      points: [Coord(slat, slon), Coord(elat, elon)],
                    ),
                  );
                }
              }
              parsed = taxiways.isNotEmpty;
            }
          }
        }

        if (!parsed && hasTaxiwayTable) {
          final taxiNameCol = taxiColumns.contains('name')
              ? 'name'
              : (taxiColumns.contains('ident') ? 'ident' : null);
          if (taxiNameCol != null) {
            final taxiResults = db.select(
              'SELECT $taxiNameCol as name FROM taxiway WHERE airport_id = ?',
              [airportId],
            );
            for (final row in taxiResults) {
              taxiways.add(
                TaxiwayInfo(name: row['name'] as String?, points: []),
              );
            }
          }
        }
      } catch (e) {
        AppLogger.error('Error parsing taxiways from LNM: $e');
      }

      return AirportDetailData(
        icaoCode: icao,
        name: airportRow['name'] as String? ?? 'Unknown',
        city: airportRow['city'] as String?,
        country: airportRow['country'] as String?,
        latitude: (airportRow[latCol] as num).toDouble(),
        longitude: (airportRow[lonCol] as num).toDouble(),
        elevation: (airportRow['altitude'] as num?)?.toInt(),
        runways: runways,
        navaids: navaids,
        frequencies: AirportFrequencies(all: frequencies),
        parkings: parkings,
        taxiways: taxiways,
        fetchedAt: DateTime.now(),
        dataSource: AirportDataSourceType.lnmData,
      );
    } catch (e) {
      AppLogger.error('Error parsing Little Navmap database: $e');
      return null;
    } finally {
      db?.dispose();
    }
  }

  /// 获取 Little Navmap 数据库中的所有机场列表
  static Future<List<Map<String, dynamic>>> getAllAirports(File dbFile) async {
    Database? db;
    try {
      if (!await dbFile.exists()) {
        AppLogger.warning(
          'LNM file not found for getAllAirports: ${dbFile.path}',
        );
        return [];
      }

      db = sqlite3.open(dbFile.path);

      // 检查表是否存在
      final tables = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='airport'",
      );
      if (tables.isEmpty) {
        AppLogger.error('LNM database does not contain "airport" table');
        return [];
      }

      final airportColumns = _getTableColumns(db, 'airport');
      if (airportColumns.isEmpty) {
        AppLogger.error('LNM airport table has no columns');
        return [];
      }

      // 关键：LNM 数据库中 ICAO 通常存储在 'ident' 列，但也有可能是 'icao'
      final identCol = airportColumns.contains('ident')
          ? 'ident'
          : (airportColumns.contains('icao') ? 'icao' : null);
      final latCol = airportColumns.contains('latitude')
          ? 'latitude'
          : (airportColumns.contains('laty')
                ? 'laty'
                : (airportColumns.contains('lat') ? 'lat' : null));
      final lonCol = airportColumns.contains('longitude')
          ? 'longitude'
          : (airportColumns.contains('lonx')
                ? 'lonx'
                : (airportColumns.contains('lon') ? 'lon' : null));
      final iataCol = airportColumns.contains('iata') ? 'iata' : null;

      if (identCol == null || latCol == null || lonCol == null) {
        AppLogger.error(
          'Could determine ident/lat/lon columns in LNM database. Available: ${airportColumns.join(', ')}',
        );
        return [];
      }

      final hasTypeCol = airportColumns.contains('type');
      // 如果有 type 且为 'H' 则是直升机场，我们通常过滤掉，但如果没有 type 则不进行过滤
      final selectIata = iataCol != null ? ", $iataCol as iata" : "";
      final query = hasTypeCol
          ? "SELECT $identCol as ident, name$selectIata, $latCol as lat, $lonCol as lon FROM airport WHERE type != 'H' AND $identCol IS NOT NULL AND $identCol != '' ORDER BY $identCol ASC"
          : "SELECT $identCol as ident, name$selectIata, $latCol as lat, $lonCol as lon FROM airport WHERE $identCol IS NOT NULL AND $identCol != '' ORDER BY $identCol ASC";
      final results = db.select(query);

      return results
          .map(
            (row) => {
              'icao': row['ident'] as String? ?? '',
              'name': row['name'] as String? ?? '',
              'iata': row.containsKey('iata')
                  ? (row['iata'] as String? ?? '')
                  : '',
              'lat': (row['lat'] as num?)?.toDouble() ?? 0.0,
              'lon': (row['lon'] as num?)?.toDouble() ?? 0.0,
            },
          )
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching all airports from LNM: $e');
      return [];
    } finally {
      db?.dispose();
    }
  }

  /// 获取表的列名列表
  static Set<String> _getTableColumns(Database db, String tableName) {
    try {
      final results = db.select('PRAGMA table_info($tableName)');
      return results.map((row) => row['name'] as String).toSet();
    } catch (e) {
      AppLogger.error('Error getting columns for table $tableName: $e');
      return {};
    }
  }
}
