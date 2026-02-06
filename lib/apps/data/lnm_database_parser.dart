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
      AppLogger.debug('LNM airport columns: ${airportColumns.join(', ')}');

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
      AppLogger.debug('LNM runway columns: ${runwayColumns.join(', ')}');

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
        // 如果有 runway_end 表，通过关联查询获取跑道标识 (如 18/36)
        final sql =
            '''
          SELECT
            re1.name || '/' || re2.name as runway_ident,
            r.length, r.width, r.surface
            ${(rLatCol != null && rLonCol != null) ? ', r.$rLatCol, r.$rLonCol' : ''}
          FROM runway r
          JOIN runway_end re1 ON r.primary_end_id = re1.runway_end_id
          JOIN runway_end re2 ON r.secondary_end_id = re2.runway_end_id
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
            'SELECT $rIdentCol as runway_ident, length, width, surface ${(rLatCol != null && rLonCol != null) ? ", $rLatCol, $rLonCol" : ""} FROM runway WHERE airport_id = ?';
        runwayRows = db.select(sql, [airportId]).map((row) => row).toList();
      }

      final runways = <RunwayInfo>[];
      for (final row in runwayRows) {
        runways.add(
          RunwayInfo(
            ident: row['runway_ident'] as String,
            lengthFt: (row['length'] as num?)?.toInt(),
            widthFt: (row['width'] as num?)?.toInt(),
            surface: row['surface'] as String?,
          ),
        );
      }

      // 3. 查询频率信息
      final comColumns = _getTableColumns(db, 'com');
      AppLogger.debug('LNM com columns: ${comColumns.join(', ')}');

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
      AppLogger.debug(
        'LNM airport table columns: ${airportColumns.join(', ')}',
      );

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

      AppLogger.debug('Executing LNM query: $query');
      final results = db.select(query);
      AppLogger.debug('LNM query returned ${results.length} rows');

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
