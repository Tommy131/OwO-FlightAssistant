import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../core/services/persistence_service.dart';
import '../../core/module_registry/module_registrar.dart';
import '../../core/module_registry/module_registry.dart';
import '../../core/module_registry/navigation/navigation_item.dart';
import '../../core/services/localization_service.dart';
import '../common/providers/common_provider.dart';
import 'localization/flight_logs_localization_keys.dart';
import 'localization/flight_logs_translations.dart';
import 'models/flight_log_models.dart';
import 'pages/flight_logs_page.dart';
import 'providers/flight_logs_provider.dart';

class FlightLogsModule implements ModuleRegistrar {
  @override
  String get moduleName => 'flight_logs';

  @override
  void register() {
    final registry = ModuleRegistry();
    LocalizationService().registerModuleTranslations(flightLogsTranslations);

    registry.providers.register(
      ChangeNotifierProxyProvider<HomeProvider, FlightLogsProvider>(
        create: (_) => FlightLogsProvider(adapter: LocalFlightLogsAdapter()),
        update: (_, commonProvider, logsProvider) {
          final provider =
              logsProvider ??
              FlightLogsProvider(adapter: LocalFlightLogsAdapter());
          provider.handleHomeSnapshot(commonProvider.snapshot);
          return provider;
        },
      ),
    );

    registry.navigation.register(
      (context) => NavigationItem(
        id: 'flight_logs',
        title: FlightLogsLocalizationKeys.navTitle.tr(context),
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long,
        page: const FlightLogsPage(),
        priority: 40,
        groupId: 'flight',
        defaultEnabled: true,
      ),
    );
  }
}

class LocalFlightLogsAdapter implements FlightLogsAdapter {
  Future<Directory?> _ensureDirectory() async {
    final persistence = PersistenceService();
    await persistence.ensureReady();
    final rootPath = persistence.rootPath;
    if (rootPath == null) return null;
    final dir = Directory(p.join(rootPath, 'flight_logs'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<List<FlightLog>> loadLogs() async {
    final dir = await _ensureDirectory();
    if (dir == null) return [];
    final entries = await dir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.json')
        .toList();
    if (entries.isEmpty) return [];
    final List<FlightLog> logs = [];
    for (final file in entries) {
      try {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        logs.addAll(_parseLogs(decoded));
      } catch (_) {}
    }
    logs.sort((a, b) => b.startTime.compareTo(a.startTime));
    return logs;
  }

  @override
  Future<void> deleteLog(String id) async {
    final dir = await _ensureDirectory();
    if (dir == null) return;
    final files = await dir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.json')
        .toList();
    for (final file in files) {
      try {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          final log = FlightLog.fromJson(decoded);
          if (log.id == id) {
            await file.delete();
            return;
          }
        } else if (decoded is List) {
          final logs = decoded
              .whereType<Map<String, dynamic>>()
              .map(FlightLog.fromJson)
              .toList();
          final remaining = logs.where((log) => log.id != id).toList();
          if (remaining.length != logs.length) {
            if (remaining.isEmpty) {
              await file.delete();
            } else {
              final payload = remaining.map((log) => log.toJson()).toList();
              await file.writeAsString(jsonEncode(payload));
            }
            return;
          }
        }
      } catch (_) {}
    }
  }

  @override
  Future<void> exportLog(FlightLog log) async {
    final filePath = await FilePicker.platform.saveFile(
      fileName: 'flight_log_${log.id}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (filePath == null) return;
    final payload = jsonEncode(log.toJson());
    await File(filePath).writeAsString(payload);
  }

  @override
  Future<void> importLog() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final filePath = result?.files.single.path;
    if (filePath == null) return;
    final content = await File(filePath).readAsString();
    final decoded = jsonDecode(content);
    final logs = _parseLogs(decoded);
    for (final log in logs) {
      await _saveLog(log);
    }
  }

  @override
  Future<void> saveLog(FlightLog log) async {
    await _saveLog(log);
  }

  List<FlightLog> _parseLogs(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      return [FlightLog.fromJson(decoded)];
    }
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(FlightLog.fromJson)
          .toList();
    }
    return [];
  }

  Future<void> _saveLog(FlightLog log) async {
    final dir = await _ensureDirectory();
    if (dir == null) return;
    final file = File(p.join(dir.path, 'flight_log_${log.id}.json'));
    await file.writeAsString(jsonEncode(log.toJson()));
  }
}
