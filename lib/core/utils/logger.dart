/*
 *        _____   _          __  _____   _____   _       _____   _____
 *      /  _  \ | |        / / /  _  \ |  _  \ | |     /  _  \ /  ___|
 *      | | | | | |  __   / /  | | | | | |_| | | |     | | | | | |
 *      | | | | | | /  | / /   | | | | |  _  { | |     | | | | | |   _
 *      | |_| | | |/   |/ /    | |_| | | |_| | | |___  | |_| | | |_| |
 *      \_____/ |___/|___/     \_____/ |_____/ |_____| \_____/ \_____/
 *
 *  Copyright (c) 2023 by OwOTeam-DGMT (OwOBlog).
 * @Date         : 2025-10-22
 * @Author       : HanskiJay
 * @LastEditors  : HanskiJay
 * @LastEditTime : 2025-10-22
 * @E-Mail       : support@owoblog.com
 * @Telegram     : https://t.me/HanskiJay
 * @GitHub       : https://github.com/Tommy131
 */

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import '../services/persistence_service.dart';

class AppLogger {
  static const String _enabledKey = 'log_enabled';
  static const String _maxSizeKey = 'log_split_size_mb';
  static const int _defaultMaxSizeMb = 5;

  static Logger _logger = _createLogger();
  static bool _enabled = true;
  static int _maxSizeMb = _defaultMaxSizeMb;
  static String? _logDirectory;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    final settings = loadSettings();
    await _configure(settings);
    _initialized = true;
  }

  static LogSettings loadSettings() {
    final persistence = PersistenceService();
    final enabled = persistence.getBool(_enabledKey) ?? true;
    final maxSizeMb = persistence.getInt(_maxSizeKey) ?? _defaultMaxSizeMb;
    return LogSettings(enabled: enabled, maxFileSizeMb: maxSizeMb);
  }

  static Future<void> updateSettings({
    bool? enabled,
    int? maxFileSizeMb,
  }) async {
    final persistence = PersistenceService();
    final nextEnabled = enabled ?? _enabled;
    final nextMaxSizeMb = maxFileSizeMb ?? _maxSizeMb;
    await persistence.setBool(_enabledKey, nextEnabled);
    await persistence.setInt(_maxSizeKey, nextMaxSizeMb);
    await _configure(
      LogSettings(enabled: nextEnabled, maxFileSizeMb: nextMaxSizeMb),
    );
  }

  static bool get isEnabled => _enabled;
  static int get maxFileSizeMb => _maxSizeMb;
  static String? get logDirectory => _logDirectory;

  static void debug(String message) => _logger.d(message);
  static void info(String message) => _logger.i(message);
  static void warning(String message) => _logger.w(message);
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  static Future<void> _configure(LogSettings settings) async {
    _enabled = settings.enabled;
    _maxSizeMb = settings.maxFileSizeMb.clamp(1, 1024);

    _logger = await _buildLogger();
  }

  static Logger _createLogger({LogOutput? fileOutput}) {
    final outputs = <LogOutput>[];

    // In debug mode, always add console output
    // In release mode, only add console if no file output is available
    if (kDebugMode || fileOutput == null) {
      outputs.add(ConsoleOutput());
    }

    if (fileOutput != null) {
      outputs.add(fileOutput);
    }

    // Ensure we always have at least one output
    if (outputs.isEmpty) {
      outputs.add(ConsoleOutput());
    }

    return Logger(
      filter: ProductionFilter(), // Explicitly allow logs in release mode
      output: MultiOutput(outputs),
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true, // Enable console colors, file logs will strip ANSI codes
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );
  }

  static Future<Logger> _buildLogger() async {
    LogOutput? fileOutput;

    if (_enabled) {
      _logDirectory = p.join(PersistenceService.getAppCacheRootPath(), 'logs');
      try {
        final logDir = Directory(_logDirectory!);
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        fileOutput = _FileLogOutput(_logDirectory!, _maxSizeMb);
        _print('File logging enabled at: $_logDirectory');
      } catch (e) {
        _print('Failed to enable file logging: $e');
      }
    } else {
      _logDirectory = null;
      _print('File logging disabled');
    }

    return _createLogger(fileOutput: fileOutput);
  }
}

class LogSettings {
  final bool enabled;
  final int maxFileSizeMb;

  const LogSettings({required this.enabled, required this.maxFileSizeMb});
}

class _FileLogOutput extends LogOutput {
  final String logDirPath;
  final int thresholdMb;
  bool _directoryVerified = false;

  _FileLogOutput(this.logDirPath, this.thresholdMb) {
    _verifyDirectory();
  }

  void _verifyDirectory() {
    try {
      final dir = Directory(logDirPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _directoryVerified = true;
    } catch (e) {
      _print('Failed to create log directory: $e');
      _directoryVerified = false;
    }
  }

  @override
  void output(OutputEvent event) {
    if (event.lines.isEmpty) return;
    if (!_directoryVerified) {
      _verifyDirectory();
      if (!_directoryVerified) return;
    }

    final content = event.lines.join('\n');
    final cleanContent = content.replaceAll(
      RegExp(r'\x1B\[[0-9;]*[A-Za-z]'),
      '',
    );
    final line = cleanContent.endsWith('\n') ? cleanContent : '$cleanContent\n';
    final isError = event.level.index >= Level.error.index;

    // Determine file name based on error level
    final fileName = isError ? 'error.log' : 'app.log';
    final filePath = p.join(logDirPath, fileName);

    _writeToFile(filePath, line);
  }

  void _writeToFile(String filePath, String line) {
    try {
      final file = File(filePath);

      // Ensure parent directory exists
      final parentDir = file.parent;
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }

      // Check rotation
      if (file.existsSync()) {
        final fileSize = file.lengthSync();
        if (fileSize > thresholdMb * 1024 * 1024) {
          _rotateLogFile(filePath);
        }
      }

      // Write synchronously to ensure it hits disk
      file.writeAsStringSync(line, mode: FileMode.append, flush: true);
    } catch (e) {
      _print('Failed to write log to file: $e');
    }
  }

  void _rotateLogFile(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return;

      final extension = p.extension(filePath);
      final fileNameWithoutExt = p.basenameWithoutExtension(filePath);

      // Use detailed timestamp for rotation
      final now = DateTime.now();
      final timestamp =
          '${now.year}${_two(now.month)}${_two(now.day)}_'
          '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';

      final newPath = p.join(
        logDirPath,
        '${fileNameWithoutExt}_$timestamp$extension',
      );

      file.renameSync(newPath);
      File(filePath).createSync();
    } catch (e) {
      _print('Failed to rotate log file: $e');
    }
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

void _print(String message) {
  if (kDebugMode) {
    print('[AppLogger] $message');
  } else {
    // In release mode, write to stderr for diagnostics if needed
    stderr.writeln('[AppLogger] $message');
  }
}
