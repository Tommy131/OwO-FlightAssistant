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
      final logDir = await AppStoragePaths.getLogDirectory();
      final normalLog = File(p.join(logDir.path, 'app.log'));
      final errorLog = File(p.join(logDir.path, 'app_error.log'));
      if (!await normalLog.exists()) {
        await normalLog.create(recursive: true);
      }
      if (!await errorLog.exists()) {
        await errorLog.create(recursive: true);
      }
      _logger.i('File logging enabled');
    } else {
      _logger.i('File logging disabled');
    }
  }

  static Logger _createLogger({LogOutput? fileOutput}) {
    final outputs = <LogOutput>[ConsoleOutput()];
    if (fileOutput != null) {
      outputs.add(fileOutput);
    }
    return Logger(
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

  _FileLogOutput(this.logDirPath, this.thresholdMb);

  @override
  void output(OutputEvent event) {
    if (event.lines.isEmpty) return;
    final content = event.lines.join('\n');
    final cleanContent = content.replaceAll(
      RegExp(r'\x1B\[[0-9;]*[A-Za-z]'),
      '',
    );
    final line = cleanContent.endsWith('\n') ? cleanContent : '$cleanContent\n';
    final isError = event.level.index >= Level.error.index;
    final fileName = isError ? 'app_error.log' : 'app.log';
    final filePath = p.join(logDirPath, fileName);
    final file = File(filePath);

    try {
      if (file.existsSync() && file.lengthSync() > thresholdMb * 1024 * 1024) {
        _rotateLogFile(filePath);
      }
      file.writeAsStringSync(line, mode: FileMode.append, flush: true);
    } catch (_) {}
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
    } catch (e) {
      // Rotation failed
    }
  }
}
