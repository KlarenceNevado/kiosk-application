import 'package:flutter/material.dart';
import '../../health_check/models/vital_signs_model.dart';

/// Abstract interface for user medical history (Vital Signs)
/// Both the standalone Web PWA and the offline-first Native apps must conform to this contract.
abstract class IHistoryRepository extends ChangeNotifier {
  List<VitalSigns> get records;
  bool get isLoading;

  /// Loads history records restricted by user ID
  Future<void> loadUserHistory(String userId);

  /// Loads all history records (Admin functionality)
  Future<void> loadAllHistory();

  /// Submits a brand-new medical record
  Future<void> addRecord(VitalSigns record);

  /// Modifies an existing medical record (e.g. adding remarks/verifications)
  Future<void> updateRecord(VitalSigns updatedRecord);

  /// completely clears the internal history array
  Future<void> clearHistory();

  /// Opens or downloads an attached Medical PDF/Image report.
  Future<void> openReport(VitalSigns record);
}
