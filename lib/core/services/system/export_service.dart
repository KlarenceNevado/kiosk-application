import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../security/encryption_service.dart';
import '../system/system_log_service.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// Exports a list of maps to an encrypted CSV file (.csv.aes)
  /// Uses AES-256 via EncryptionService.
  Future<File?> exportToEncryptedCsv({
    required String fileName,
    required List<List<dynamic>> rows,
    required String actionLabel,
    String? userId,
  }) async {
    try {
      // 1. Audit Log: Start Export
      await SystemLogService().logAction(
        action: 'DATA_EXPORT_START',
        module: 'ADMIN_COMMAND',
        severity: 'INFO',
        userId: userId,
        sensorFailures: 'Exporting $actionLabel: ${rows.length} records',
      );

      // 2. Generate CSV String
      const converter = ListToCsvConverter();
      final csvString = converter.convert(rows);

      // 3. Encrypt the entire CSV content (AES-256)
      final encryptedContent = EncryptionService().encryptData(csvString);

      // 4. Determine save path
      Directory? directory;
      if (Platform.isWindows || Platform.isLinux) {
        directory = await getDownloadsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception("Could not find a valid storage directory.");
      }

      final fullPath = '${directory.path}/$fileName.csv.aes';
      final file = File(fullPath);

      // 5. Write to file
      await file.writeAsString(encryptedContent);

      // 6. Audit Log: Success
      await SystemLogService().logAction(
        action: 'DATA_EXPORT_SUCCESS',
        module: 'ADMIN_COMMAND',
        severity: 'MEDIUM',
        userId: userId,
        sensorFailures: 'File saved to: $fullPath',
      );

      debugPrint("🔐 ExportService: Encrypted export saved to $fullPath");
      return file;
    } catch (e) {
      debugPrint("❌ ExportService: Export failed: $e");

      await SystemLogService().logAction(
        action: 'DATA_EXPORT_FAILURE',
        module: 'ADMIN_COMMAND',
        severity: 'HIGH',
        userId: userId,
        sensorFailures: 'Error: $e',
      );

      return null;
    }
  }

  /// Verification Helper: Static check for decryption integrity
  bool verifyDecryption(String encryptedPayload, String expectedHeader) {
    try {
      final decrypted = EncryptionService().decryptData(encryptedPayload);
      return decrypted.startsWith(expectedHeader);
    } catch (_) {
      return false;
    }
  }
}
