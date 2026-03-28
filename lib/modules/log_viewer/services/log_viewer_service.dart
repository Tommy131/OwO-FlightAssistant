import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/services/persistence_service.dart';
import '../../../core/utils/logger.dart';

class LogEntry {
  final String timestamp;
  final String level;
  final String message;
  final String raw;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.raw,
  });
}

class LogViewerService {
  static Future<List<LogEntry>> readLogs(String fileName) async {
    final persistence = PersistenceService();
    await persistence.ensureReady();
    final logDir =
        AppLogger.logDirectory ??
        p.join(
          await PersistenceService.getAppCacheRootPath(
            rootPath: persistence.rootPath,
          ),
          'logs',
        );
    final logDirectory = Directory(logDir);
    if (!await logDirectory.exists()) {
      return [];
    }

    final logFiles = await _resolveLogFiles(logDirectory, fileName);
    if (logFiles.isEmpty) {
      return [];
    }

    final entries = <LogEntry>[];
    try {
      for (final file in logFiles) {
        final content = await file.readAsString();
        if (content.trim().isEmpty) {
          continue;
        }
        final blocks = _splitLogBlocks(content);
        for (final block in blocks.reversed) {
          entries.add(_parseLogBlock(block));
        }
      }
    } catch (e) {
      AppLogger.error('Failed to read log file: $e', e);
      return [];
    }

    return entries;
  }

  static LogEntry _parseLogBlock(String block) {
    final normalized = block.trim();
    final lines = normalized.split('\n');
    String level = 'INFO';

    // Try to find the level in the stack trace or header lines first (more accurate)
    // PrettyPrinter typically includes the method name which might contain the level name
    // We should prioritize the actual log content/emoji
    bool found = false;

    // 1. Check for Emojis (Most reliable for PrettyPrinter)
    if (normalized.contains('⛔')) {
      level = 'ERROR';
      found = true;
    } else if (normalized.contains('⚠️')) {
      level = 'WARNING';
      found = true;
    } else if (normalized.contains('🐛')) {
      level = 'DEBUG';
      found = true;
    } else if (normalized.contains('💡')) {
      level = 'INFO';
      found = true;
    }

    // 2. If no emoji, check for explicit method calls in the stack trace lines (e.g., AppLogger.warning)
    if (!found) {
      for (final line in lines) {
        if (line.contains('AppLogger.error')) {
          level = 'ERROR';
          found = true;
          break;
        } else if (line.contains('AppLogger.warning')) {
          level = 'WARNING';
          found = true;
          break;
        } else if (line.contains('AppLogger.debug')) {
          level = 'DEBUG';
          found = true;
          break;
        } else if (line.contains('AppLogger.info')) {
          level = 'INFO';
          found = true;
          break;
        }
      }
    }

    // 3. Fallback to keyword search in the whole block, but be careful with word boundaries
    if (!found) {
      final upper = normalized.toUpperCase();
      if (upper.contains('ERROR')) {
        level = 'ERROR';
      } else if (upper.contains('WARN')) {
        level = 'WARNING';
      } else if (upper.contains('DEBUG')) {
        level = 'DEBUG';
      } else if (upper.contains('INFO')) {
        level = 'INFO';
      }
    }

    final timestampMatch = RegExp(
      r'(\d{2}:\d{2}:\d{2}(?:\.\d{3})?(?:\s*\(\+[^)]+\))?)',
    ).firstMatch(normalized);
    final timestamp = timestampMatch?.group(1) ?? '';

    return LogEntry(
      timestamp: timestamp,
      level: level,
      message: normalized,
      raw: normalized,
    );
  }

  static List<String> _splitLogBlocks(String content) {
    final normalized = content.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return const [];
    }

    if (normalized.contains('┌')) {
      return normalized
          .split(RegExp(r'(?=┌)'))
          .map((block) => block.trim())
          .where((block) => block.isNotEmpty)
          .toList();
    }

    final byParagraph = normalized
        .split(RegExp(r'\n{2,}'))
        .map((block) => block.trim())
        .where((block) => block.isNotEmpty)
        .toList();
    if (byParagraph.length > 1) {
      return byParagraph;
    }

    return normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static Future<List<File>> _resolveLogFiles(
    Directory logDirectory,
    String fileName,
  ) async {
    final targetFileName = p.basename(fileName);
    final extension = p.extension(targetFileName);
    final baseName = p.basenameWithoutExtension(targetFileName);

    final files = <File>[];
    await for (final entity in logDirectory.list(recursive: false)) {
      if (entity is! File) {
        continue;
      }

      final name = p.basename(entity.path);
      final isCurrent = name == targetFileName;
      final isRotated =
          name.startsWith('${baseName}_') && name.endsWith(extension);
      if (isCurrent || isRotated) {
        files.add(entity);
      }
    }

    files.sort((a, b) {
      final aTime = a.statSync().modified;
      final bTime = b.statSync().modified;
      return bTime.compareTo(aTime);
    });
    return files;
  }
}
