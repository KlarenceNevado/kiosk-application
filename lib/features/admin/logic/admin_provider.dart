import 'dart:async';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/database/database_helper.dart';
import '../../user_history/data/history_repository.dart';
import '../../health_check/models/vital_signs_model.dart';

class AdminProvider extends ChangeNotifier {
  // System Status State
  String _networkStatus = "Checking...";
  Color _networkColor = Colors.grey;
  String _storageStatus = "Checking...";
  bool _isMaintenanceMode = false;

  // Getters
  String get networkStatus => _networkStatus;
  Color get networkColor => _networkColor;
  String get storageStatus => _storageStatus;
  bool get isMaintenanceMode => _isMaintenanceMode;

  // Initialize Dashboard Data
  Future<void> initDashboard() async {
    await checkSystemHealth();
    // Simulate checking storage
    await Future.delayed(const Duration(milliseconds: 600));
    _storageStatus = "85% Free";
    notifyListeners();
  }

  // Check Network Health
  Future<void> checkSystemHealth() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _networkStatus = "Offline";
      _networkColor = Colors.orange;
    } else {
      _networkStatus = "Online";
      _networkColor = AppColors.brandGreen;
    }
    notifyListeners();
  }

  // Toggle Maintenance Mode (e.g., disable patient login)
  void toggleMaintenanceMode() {
    _isMaintenanceMode = !_isMaintenanceMode;
    // Log this action for security
    DatabaseHelper.instance.logSecurityEvent("MAINTENANCE_TOGGLE",
        "Maintenance mode ${_isMaintenanceMode ? 'ENABLED' : 'DISABLED'}",
        userId: "ADMIN");
    notifyListeners();
  }

  // Secure Export to CSV
  Future<String> exportDataToCSV(List<VitalSigns> records) async {
    if (records.isEmpty) {
      throw Exception("No records to export.");
    }

    List<List<dynamic>> csvData = [
      [
        "ID",
        "Timestamp",
        "Heart Rate",
        "Systolic BP",
        "Diastolic BP",
        "Oxygen",
        "Temperature"
      ],
    ];

    for (var r in records) {
      csvData.add([
        r.id,
        r.timestamp.toIso8601String(),
        r.heartRate,
        r.systolicBP,
        r.diastolicBP,
        r.oxygen,
        r.temperature
      ]);
    }

    String csvString = const ListToCsvConverter().convert(csvData);

    final directory = await getApplicationDocumentsDirectory();
    final path =
        "${directory.path}/kiosk_export_${DateTime.now().millisecondsSinceEpoch}.csv";
    final file = File(path);
    await file.writeAsString(csvString);

    await DatabaseHelper.instance.logSecurityEvent(
        "DATA_EXPORT", "Exported ${records.length} records",
        userId: "ADMIN");

    return path;
  }

  // Clear Database
  Future<void> clearDatabase(HistoryRepository historyRepo) async {
    await historyRepo.clearHistory();
    await DatabaseHelper.instance.logSecurityEvent(
        "DB_WIPE", "Database cleared by Admin",
        userId: "ADMIN");
    await historyRepo.loadAllHistory();
  }
}
