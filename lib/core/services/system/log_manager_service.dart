import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum LogSeverity { info, warning, error, critical }

class LogManagerService {
  static final LogManagerService _instance = LogManagerService._internal();
  factory LogManagerService() => _instance;
  LogManagerService._internal();

  static const String _diagnosticsDirName = 'diagnostics';
  static const int _maxLogAgeDays = 7;
  Timer? _maintenanceTimer;

  /// Initializes the diagnostics directory and performs a background cleanup.
  Future<void> initialize() async {
    if (kIsWeb) return;

    try {
      final baseDir = await _getDiagnosticsDirectory();
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
        debugPrint("📂 [LogManagerService] Created diagnostics directory.");
      }
      
      // Perform initial cleanup
      await _cleanupOldLogs();
    } catch (e) {
      debugPrint("❌ [LogManagerService] initialization error: $e");
    }
  }

  /// Starts a periodic background task to clean up old logs.
  void startLogMaintenance() {
    _maintenanceTimer?.cancel();
    // Run cleanup every 24 hours
    _maintenanceTimer = Timer.periodic(const Duration(hours: 24), (_) => _cleanupOldLogs());
    debugPrint("⚙️ [LogManagerService] Background log maintenance started.");
  }

  /// Writes a structured event to the log.
  Future<void> logEvent(String eventName, String details, {LogSeverity severity = LogSeverity.info}) async {
    final severityStr = severity.toString().split('.').last.toUpperCase();
    final message = "[$severityStr] [$eventName] $details";
    await log(message);
  }

  /// Writes a message to the primary system log file in the diagnostics folder.
  Future<void> log(String message, {String fileName = 'system_runtime.log'}) async {
    if (kIsWeb) {
      debugPrint(message);
      return;
    }

    try {
      final diagnosticsDir = await _getDiagnosticsDirectory();
      final logFile = File(p.join(diagnosticsDir.path, fileName));
      
      final timestamp = DateTime.now().toIso8601String();
      await logFile.writeAsString(
        "[$timestamp] $message\n", 
        mode: FileMode.append, 
        flush: true
      );
    } catch (e) {
      debugPrint("⚠️ [LogManagerService] Log write error: $e");
    }
  }

  /// Rotates the current log file to a dated archive.
  Future<void> rotateLog({String fileName = 'system_runtime.log'}) async {
    if (kIsWeb) return;

    try {
      final diagnosticsDir = await _getDiagnosticsDirectory();
      final currentFile = File(p.join(diagnosticsDir.path, fileName));
      
      if (await currentFile.exists()) {
        final dateStr = DateTime.now().toIso8601String().split('T').first;
        final archiveName = "${p.basenameWithoutExtension(fileName)}_$dateStr.log";
        await currentFile.rename(p.join(diagnosticsDir.path, archiveName));
        debugPrint("♻️ [LogManagerService] Rotated log to $archiveName");
      }
    } catch (e) {
      debugPrint("❌ [LogManagerService] Log rotation error: $e");
    }
  }

  /// Deletes logs older than [_maxLogAgeDays] days.
  Future<void> _cleanupOldLogs() async {
    try {
      final diagnosticsDir = await _getDiagnosticsDirectory();
      if (!await diagnosticsDir.exists()) return;

      final now = DateTime.now();
      final List<FileSystemEntity> files = diagnosticsDir.listSync();

      for (var file in files) {
        if (file is File && p.extension(file.path) == '.log') {
          final stat = await file.stat();
          final ageDays = now.difference(stat.modified).inDays;

          if (ageDays >= _maxLogAgeDays) {
            await file.delete();
            debugPrint("🗑️ [LogManagerService] Deleted expired log: ${p.basename(file.path)}");
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ [LogManagerService] Cleanup error: $e");
    }
  }

  /// Resolves the absolute path to the diagnostics directory.
  Future<Directory> _getDiagnosticsDirectory() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      final Directory localDir = Directory(p.join(Directory.current.path, _diagnosticsDirName));
      return localDir;
    }
    
    final appSupportDir = await getApplicationSupportDirectory();
    return Directory(p.join(appSupportDir.path, _diagnosticsDirName));
  }

  /// Returns the content of a specific log file.
  Future<String> getLogContent(String fileName) async {
    try {
      final dir = await _getDiagnosticsDirectory();
      final file = File(p.join(dir.path, fileName));
      if (await file.exists()) {
        return await file.readAsString();
      }
      return "Log file $fileName not found.";
    } catch (e) {
      return "Error reading log: $e";
    }
  }

  /// Lists all log files in the diagnostics directory.
  Future<List<String>> listLogs() async {
    try {
      final dir = await _getDiagnosticsDirectory();
      if (!await dir.exists()) return [];
      
      final entities = await dir.list().toList();
      return entities
          .whereType<File>()
          .where((f) => p.extension(f.path) == '.log')
          .map((f) => p.basename(f.path))
          .toList()
        ..sort((a, b) => b.compareTo(a)); // Newest first by filename
    } catch (e) {
      debugPrint("❌ [LogManagerService] Error listing logs: $e");
      return [];
    }
  }
}


