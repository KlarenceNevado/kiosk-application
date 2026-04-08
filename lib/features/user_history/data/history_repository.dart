import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/database/database_helper.dart';
import '../../../core/services/database/sync_service.dart';
import '../../../core/services/system/sync_event_bus.dart';
import '../../../features/health_check/models/vital_signs_model.dart';
import '../../../core/services/system/file_storage_service.dart';
import 'package:open_file/open_file.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/i_history_repository.dart';

class LocalHistoryRepository extends ChangeNotifier
    implements IHistoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<VitalSigns> _records = [];
  bool _isLoading = false;
  StreamSubscription? _syncSubscription;
  Timer? _debounceTimer;

  LocalHistoryRepository() {
    _syncSubscription = SyncEventBus.instance.vitalsStream.listen((_) {
      // Debounce: Coalesce rapid sync events into a single reload
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 1), () {
        debugPrint(
            "🔔 HistoryRepository: Sync event detected. Refreshing data...");
        if (_records.isNotEmpty) {
          loadAllHistory();
        }
      });
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  List<VitalSigns> get records => List.unmodifiable(_records);
  @override
  bool get isLoading => _isLoading;

  /// Loads data ONLY for the specific user
  @override
  Future<void> loadUserHistory(String userId) async {
    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      if (kIsWeb) {
        // Phase 4: PWA Cloud-only fetch (SQLite is not available on Web)
        final response = await Supabase.instance.client
            .from('vitals')
            .select()
            .eq('user_id', userId)
            .order('timestamp', ascending: false);

        _records =
            (response as List).map((data) => VitalSigns.fromMap(data)).toList();
      } else {
        _records = await _dbHelper.getRecordsByUserId(userId);
      }
    } catch (e) {
      debugPrint("Error loading user history: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads ALL data regardless of user (Admin privilege required)
  @override
  Future<void> loadAllHistory() async {
    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      if (kIsWeb) {
        // Phase 4: PWA Cloud-only fetch
        final response = await Supabase.instance.client
            .from('vitals')
            .select()
            .order('timestamp', ascending: false);

        _records =
            (response as List).map((data) => VitalSigns.fromMap(data)).toList();
      } else {
        _records = await _dbHelper.getAllRecords();
      }
    } catch (e) {
      debugPrint("Error loading all history: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  Future<void> addRecord(VitalSigns record) async {
    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      await _dbHelper.createRecord(record);
      // Add to local list (prepend)
      _records.insert(0, record);
      debugPrint("✅ Saved record for user ${record.userId}");

      // Trigger Cloud Sync for the new Vital Sign
      SyncService().createVitalSign(record);
    } catch (e) {
      debugPrint("❌ Failed to save record: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  Future<void> updateRecord(VitalSigns updatedRecord) async {
    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      await _dbHelper.updateRecord(updatedRecord);
      final index = _records.indexWhere((r) => r.id == updatedRecord.id);
      if (index != -1) {
        _records[index] = updatedRecord;
      }
      debugPrint("✅ Updated record validation status.");

      // Trigger Cloud Sync for the Updated Status
      SyncService().updateVitalSign(updatedRecord);
    } catch (e) {
      debugPrint("❌ Failed to update record: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  Future<void> clearHistory() async {
    try {
      await _dbHelper.clearHistory();
      _records.clear();
      notifyListeners();
    } catch (e) {
      debugPrint("Error clearing history: $e");
    }
  }

  @override
  Future<void> openReport(VitalSigns record) async {
    if (record.reportPath != null && await File(record.reportPath!).exists()) {
      await OpenFile.open(record.reportPath!);
      return;
    }

    if (record.reportUrl != null) {
      _isLoading = true;
      Future.microtask(() => notifyListeners());
      try {
        final file =
            await FileStorageService().getCachedFile(record.reportUrl!);
        if (file != null) {
          // Update record with local path
          final updatedRecord = VitalSigns(
            id: record.id,
            userId: record.userId,
            timestamp: record.timestamp,
            heartRate: record.heartRate,
            systolicBP: record.systolicBP,
            diastolicBP: record.diastolicBP,
            oxygen: record.oxygen,
            temperature: record.temperature,
            bmi: record.bmi,
            bmiCategory: record.bmiCategory,
            status: record.status,
            remarks: record.remarks,
            followUpAction: record.followUpAction,
            reportUrl: record.reportUrl,
            reportPath: file.path,
          );

          await _dbHelper.updateRecordRaw(record.id, {
            'report_path': file.path,
          });

          final index = _records.indexWhere((r) => r.id == record.id);
          if (index != -1) {
            _records[index] = updatedRecord;
          }

          await OpenFile.open(file.path);
        }
      } catch (e) {
        debugPrint("Error opening remote report: $e");
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } else {
      debugPrint("No report available for this record.");
    }
  }
}
