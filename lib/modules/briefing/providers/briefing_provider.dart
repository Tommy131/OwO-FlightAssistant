import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../core/services/persistence_service.dart';

class BriefingRecord {
  final String title;
  final String content;
  final DateTime createdAt;

  const BriefingRecord({
    required this.title,
    required this.content,
    required this.createdAt,
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
}

class BriefingProvider extends ChangeNotifier {
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
  }) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 200));
    final summary = StringBuffer()
      ..writeln('DEP: ${departure.isEmpty ? "--" : departure}')
      ..writeln('ARR: ${arrival.isEmpty ? "--" : arrival}')
      ..writeln('ALT: ${alternate?.isNotEmpty == true ? alternate : "--"}')
      ..writeln(
        'FLT: ${flightNumber?.isNotEmpty == true ? flightNumber : "--"}',
      )
      ..writeln('RTE: ${route?.isNotEmpty == true ? route : "--"}')
      ..writeln('CRZ: ${cruiseAltitude != null ? "$cruiseAltitude ft" : "--"}');
    final record = BriefingRecord(
      title:
          '${departure.isNotEmpty ? departure : "--"} → ${arrival.isNotEmpty ? arrival : "--"}',
      content: summary.toString(),
      createdAt: DateTime.now(),
    );
    _latest = record;
    _history.insert(0, record);
    await _saveRecord(record);
    _isLoading = false;
    notifyListeners();
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
    await File(filePath)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
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

  Future<void> _saveRecord(BriefingRecord record) async {
    final dir = await _ensureDirectory();
    if (dir == null) return;
    final fileName =
        'briefing_${record.createdAt.millisecondsSinceEpoch}.json';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(record.toJson()),
    );
  }

  Future<List<BriefingRecord>> _loadFromFile(File file) async {
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return [BriefingRecord.fromJson(decoded)];
      }
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(BriefingRecord.fromJson)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
