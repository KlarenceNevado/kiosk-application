import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../health_check/models/vital_signs_model.dart';
import '../../../core/services/security/encryption_service.dart';

import '../domain/i_history_repository.dart';

/// Web-safe HistoryRepository that uses Supabase directly.
/// No DatabaseHelper, SyncService, FileStorageService, dart:io, or open_file.
class WebHistoryRepository extends ChangeNotifier implements IHistoryRepository {
  final _supabase = Supabase.instance.client;
  final _encryption = EncryptionService();
  List<VitalSigns> _records = [];
  bool _isLoading = false;

  @override
  List<VitalSigns> get records => List.unmodifiable(_records);
  @override
  bool get isLoading => _isLoading;

  /// Decrypts encrypted vital fields from Supabase before mapping to model.
  Map<String, dynamic> _decryptVitalsRow(Map<String, dynamic> row) {
    final decrypted = Map<String, dynamic>.from(row);
    const encryptedFields = ['heart_rate', 'systolic_bp', 'diastolic_bp', 'oxygen', 'temperature'];
    for (final field in encryptedFields) {
      if (decrypted[field] != null && decrypted[field] is String) {
        final raw = _encryption.decryptData(decrypted[field] as String);
        // Try parsing back to number
        decrypted[field] = int.tryParse(raw) ?? double.tryParse(raw) ?? raw;
      }
    }
    return decrypted;
  }

  /// Loads vitals ONLY for a specific user from Supabase
  @override
  Future<void> loadUserHistory(String userId) async {
    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      final response = await _supabase
          .from('vitals')
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .order('timestamp', ascending: false);

      final List<dynamic> data = response as List;
      _records = data.map((row) => VitalSigns.fromMap(_decryptVitalsRow(row))).toList();
    } catch (e) {
      debugPrint("Error loading user history from cloud: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads ALL vitals from Supabase (Admin only)
  @override
  Future<void> loadAllHistory() async {
    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      final response = await _supabase
          .from('vitals')
          .select()
          .eq('is_deleted', false)
          .order('timestamp', ascending: false);

      final List<dynamic> data = response as List;
      _records = data.map((row) => VitalSigns.fromMap(_decryptVitalsRow(row))).toList();
    } catch (e) {
      debugPrint("Error loading all history from cloud: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Stubs for methods that are native-only (no local DB on web)
  @override
  Future<void> addRecord(VitalSigns record) async {
    debugPrint("⚠️ Web: addRecord is a no-op. Vitals are recorded at the Kiosk.");
  }

  @override
  Future<void> updateRecord(VitalSigns updatedRecord) async {
    debugPrint("⚠️ Web: updateRecord is a no-op.");
  }

  @override
  Future<void> clearHistory() async {
    debugPrint("⚠️ Web: clearHistory is a no-op.");
  }

  @override
  Future<void> openReport(VitalSigns record) async {
    // On web, open the report URL directly in a new tab if available
    if (record.reportUrl != null) {
      debugPrint("📄 Web: Report URL: ${record.reportUrl}");
      // In a real browser, this would open a new tab — handled by the UI layer.
    } else {
      debugPrint("No report available for this record.");
    }
  }
}
