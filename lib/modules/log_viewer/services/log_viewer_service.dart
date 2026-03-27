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
    final logDir = AppLogger.logDirectory ?? 
        p.join(PersistenceService.getAppCacheRootPath(), 'logs');
    final logFile = File(p.join(logDir, fileName));

    if (!await logFile.exists()) {
      return [];
    }

    try {
      final content = await logFile.readAsString();
      if (content.isEmpty) return [];

      // Split by the start of a PrettyPrinter block (┌)
      // We use a regex to split while keeping the delimiter
      final blocks = content.split(RegExp(r'(?=┌)'));
      
      final entries = <LogEntry>[];
      for (final block in blocks) {
        if (block.trim().isEmpty) continue;
        entries.add(_parseLogBlock(block));
      }

      // Reverse to show latest first
      return entries.reversed.toList();
    } catch (e) {
      AppLogger.error('Failed to read log file: $e');
      return [];
    }
  }

  static LogEntry _parseLogBlock(String block) {
    // Determine level based on emojis or keywords in the block
    String level = 'INFO';
    if (block.contains('⛔') || block.contains('ERROR')) {
      level = 'ERROR';
    } else if (block.contains('⚠️') || block.contains('WARN')) {
      level = 'WARNING';
    } else if (block.contains('🐛') || block.contains('DEBUG')) {
      level = 'DEBUG';
    } else if (block.contains('💡') || block.contains('INFO')) {
      level = 'INFO';
    }

    // Extract timestamp
    // Example format in PrettyPrinter: "│ 20:32:58.141 (+0:00:52.476112)"
    final timestampMatch = RegExp(r'│\s(\d{2}:\d{2}:\d{2}\.\d{3}.*?)\s').firstMatch(block);
    final timestamp = timestampMatch?.group(1) ?? '';

    // Clean up the block: remove the box-drawing characters for cleaner display
    // But keep the structure if needed. For now, let's keep it but remove the leading/trailing empty lines.
    final cleanMessage = block.trim();

    return LogEntry(
      timestamp: timestamp,
      level: level,
      message: cleanMessage,
      raw: block,
    );
  }
}
