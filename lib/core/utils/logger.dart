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
import '../services/persistence/app_storage_paths.dart';
import '../services/persistence/persistence_service.dart';

class AppLogger {
  static const String fileLoggingEnabledKey = 'app_file_logging_enabled';
  static const String logRotationThresholdKey = 'app_log_rotation_threshold_mb';

  static Logger _logger = _createLogger();
  static bool _fileLoggingEnabled = false;
  static int _rotationThresholdMb = 2; // Default 2MB
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    final persistence = PersistenceService();
    _fileLoggingEnabled = persistence.getBool(fileLoggingEnabledKey) ?? false;
    _rotationThresholdMb = persistence.getInt(logRotationThresholdKey) ?? 2;
    _logger = await _buildLogger();
    _initialized = true;
  }

  static Future<bool> isFileLoggingEnabled() async {
    return PersistenceService().getBool(fileLoggingEnabledKey) ?? false;
  }

  static Future<int> getLogRotationThreshold() async {
    return PersistenceService().getInt(logRotationThresholdKey) ?? 2;
  }

  static Future<void> setLogRotationThreshold(int mb) async {
    await PersistenceService().setInt(logRotationThresholdKey, mb);
    _rotationThresholdMb = mb;
    _logger = await _buildLogger();
  }

  static Future<void> setFileLoggingEnabled(bool enabled) async {
    await PersistenceService().setBool(fileLoggingEnabledKey, enabled);
    _fileLoggingEnabled = enabled;
    _logger = await _buildLogger();
    if (enabled) {
      try {
        final logDir = await AppStoragePaths.getLogDirectory();
        final normalLog = File(p.join(logDir.path, 'app.log'));
        final errorLog = File(p.join(logDir.path, 'app_error.log'));

        // Ensure log directory exists
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }

        // Create log files if they don't exist
        if (!await normalLog.exists()) {
          await normalLog.create(recursive: true);
        }
        if (!await errorLog.exists()) {
          await errorLog.create(recursive: true);
        }

        _logger.i('File logging enabled at: ${logDir.path}');
      } catch (e, stackTrace) {
        _print('Failed to enable file logging: $e');
        _print('Stack trace: $stackTrace');
        _logger.w('File logging enabled but directory setup failed: $e');
      }
    } else {
      _logger.i('File logging disabled');
    }
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
      filter: ProductionFilter(), // 明确指定在生产环境下也进行日志记录
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: MultiOutput(outputs),
    );
  }

  static Future<Logger> _buildLogger() async {
    LogOutput? fileOutput;
    if (_fileLoggingEnabled) {
      final logDir = await AppStoragePaths.getLogDirectory();
      fileOutput = _FileLogOutput(logDir.path, _rotationThresholdMb);
    }
    return _createLogger(fileOutput: fileOutput);
  }

  static void debug(String message) => _logger.d(message);
  static void info(String message) => _logger.i(message);
  static void warning(String message) => _logger.w(message);
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}

class _FileLogOutput extends LogOutput {
  final String logDirPath;
  final int thresholdMb;
  bool _directoryVerified = false;

  _FileLogOutput(this.logDirPath, this.thresholdMb) {
    // Log initialization info
    _print(
      'Initializing file logger in ${kDebugMode ? 'DEBUG' : 'RELEASE'} mode',
    );
    _print('Log directory: $logDirPath');
    _print('Rotation threshold: ${thresholdMb}MB');

    // Verify directory exists on creation
    _verifyDirectory();

    if (_directoryVerified) {
      _print('Log directory verified successfully');
    }
  }

  void _verifyDirectory() {
    try {
      final dir = Directory(logDirPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _directoryVerified = true;
    } catch (e) {
      // Print to console if directory creation fails
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
    final fileName = isError ? 'app_error.log' : 'app.log';
    final filePath = p.join(logDirPath, fileName);

    _print('Attempting to write ${event.level.name} log to: $filePath');

    // Use async write in a separate isolate to avoid blocking
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

      // Check file size and rotate if needed
      if (file.existsSync()) {
        final fileSize = file.lengthSync();
        if (fileSize > thresholdMb * 1024 * 1024) {
          _rotateLogFile(filePath);
        }
      }

      // Write to file with flush to ensure data is written immediately
      file.writeAsStringSync(line, mode: FileMode.append, flush: true);
    } catch (e) {
      // Print to console if file write fails (for debugging production issues)
      _print('Failed to write log to file: $e');
    }
  }

  void _rotateLogFile(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return;

      final extension = p.extension(filePath);
      final fileNameWithoutExt = p.basenameWithoutExtension(filePath);
      final timestamp = DateTime.now()
          .toString()
          .replaceAll(':', '-')
          .replaceAll(' ', '_')
          .split('.')
          .first;
      final newPath = p.join(
        logDirPath,
        '${fileNameWithoutExt}_$timestamp$extension',
      );

      file.renameSync(newPath);

      // Create new empty file
      File(filePath).createSync();
    } catch (e) {
      // Print to console if rotation fails
      _print('Failed to rotate log file: $e');
    }
  }
}

void _print(String message) {
  if (kDebugMode) {
    print(message);
  } else {
    // In release mode, write to stderr for diagnostics
    stderr.writeln('[AppLogger] $message');
  }
}
