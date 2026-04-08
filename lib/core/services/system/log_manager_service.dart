import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LogManagerService {
  static final LogManagerService _instance = LogManagerService._internal();
  factory LogManagerService() => _instance;
  LogManagerService._internal();

  static const String _diagnosticsDirName = 'diagnostics';
  static const int _maxLogAgeDays = 7;

  /// Initializes the diagnostics directory and performs a background cleanup.
  Future<void> initialize() async {
    if (kIsWeb) return;

    try {
      final baseDir = await _getDiagnosticsDirectory();
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
        debugPrint("📂 [LogManagerService] Created diagnostics directory.");
      }
      
      // Perform cleanup in the background
      unawaited(_cleanupOldLogs());
    } catch (e) {
      debugPrint("❌ [LogManagerService] initialization error: $e");
    }
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
    // We attempt to find the project root or the app support dir.
    // On the Pi/Linux, we target the workspace-relative diagnostics if available, 
    // otherwise the system app support path.
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // In development/kiosk, we often have a local diagnostics folder in the bin/work dir.
      final Directory localDir = Directory(p.join(Directory.current.path, _diagnosticsDirName));
      return localDir;
    }
    
    final appSupportDir = await getApplicationSupportDirectory();
    return Directory(p.join(appSupportDir.path, _diagnosticsDirName));
  }
}
