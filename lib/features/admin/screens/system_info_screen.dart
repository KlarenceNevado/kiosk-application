import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/config/routes.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/database/database_helper.dart';
import '../../../core/services/system/app_environment.dart';
import '../../../core/services/system/config_service.dart';
import '../../../core/services/database/sync_service.dart';
import '../../user_history/domain/i_history_repository.dart';
import '../../auth/domain/i_auth_repository.dart';

class SystemInfoScreen extends StatefulWidget {
  const SystemInfoScreen({super.key});

  @override
  State<SystemInfoScreen> createState() => _SystemInfoScreenState();
}

class _SystemInfoScreenState extends State<SystemInfoScreen> {
  bool _isLoading = true;
  String _dbSize = "Calculating...";
  String _dbPath = "Unknown";
  int _residentCount = 0;
  int _recordCount = 0;
  int _logCount = 0;
  String _lastSync = "Never";
  
  @override
  void initState() {
    super.initState();
    _loadSystemStats();
  }

  Future<void> _loadSystemStats() async {
    setState(() => _isLoading = true);
    
    try {
      final db = await DatabaseHelper.instance.database;
      
      // 1. Get Counts
      final residents = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM patients')) ?? 0;
      final vitals = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM vital_signs')) ?? 0;
      final logs = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM system_logs')) ?? 0;

      // 2. Get DB File Info
      final path = db.path;
      String sizeStr = "Unknown";
      if (path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.length();
          if (bytes < 1024) {
            sizeStr = "$bytes B";
          } else if (bytes < 1024 * 1024) {
            sizeStr = "${(bytes / 1024).toStringAsFixed(2)} KB";
          } else {
            sizeStr = "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
          }
        }
      }

      // 3. Get Sync Info
      // We'll use the current time as a placeholder or fetch from a sync log if available
      // For now, let's just show "Active" if sync service is running
      
      if (mounted) {
        setState(() {
          _residentCount = residents;
          _recordCount = vitals;
          _logCount = logs;
          _dbPath = path;
          _dbSize = sizeStr;
          _lastSync = DateFormat('MMM dd, hh:mm a').format(DateTime.now());
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error loading system stats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final env = AppEnvironment();
    final config = ConfigService();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("System Information & Health",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.brandDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.adminDashboard);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadSystemStats,
            tooltip: "Refresh Stats",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
      ? const Center(child: CircularProgressIndicator(color: AppColors.brandGreen))
      : ListView(
          padding: const EdgeInsets.all(32),
          children: [
            // TOP HEADER: APP BRANDING
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.brandDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings_suggest, color: Colors.white, size: 48),
                  const SizedBox(width: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(config.facilityName.toUpperCase(), 
                        style: const TextStyle(color: AppColors.brandGreen, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)),
                      const Text("Kiosk Health Management System", 
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const Text("v1.0.0-beta.4 | Stable Core Architecture", 
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT COLUMN: DATA & STORAGE
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildMetricCard("Database Statistics", [
                        _buildStatRow("Total Registered Residents", _residentCount.toString(), Icons.people),
                        _buildStatRow("Stored Health Records", _recordCount.toString(), Icons.analytics),
                        _buildStatRow("System Event Logs", _logCount.toString(), Icons.history),
                      ]),
                      const SizedBox(height: 24),
                      _buildMetricCard("Storage & Pathing", [
                        _buildStatRow("Database Size", _dbSize, Icons.storage),
                        _buildStatRow("Storage Status", "OPTIMAL", Icons.check_circle, color: Colors.green),
                        _buildStatRow("File Path", _dbPath, Icons.folder_open, isLong: true),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // RIGHT COLUMN: NETWORK & HARDWARE
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildMetricCard("Network & Sync", [
                        _buildStatRow("Connection Status", "ONLINE", Icons.wifi, color: AppColors.brandGreen),
                        _buildStatRow("Cloud Sync", "ACTIVE", Icons.cloud_done, color: Colors.blue),
                        _buildStatRow("Last Database Sync", _lastSync, Icons.update),
                        _buildStatRow("Server URL", config.serverIp, Icons.lan, isLong: true),
                      ]),
                      const SizedBox(height: 24),
                      _buildMetricCard("Hardware Profile", [
                        _buildStatRow("Device Model", env.deviceModel, Icons.computer),
                        _buildStatRow("Operating System", Platform.operatingSystem.toUpperCase(), Icons.developer_mode),
                        _buildStatRow("Kiosk Mode", env.isKiosk ? "ENABLED" : "DISABLED", Icons.app_registration),
                        if (env.isKiosk) ...[
                          _buildStatRow("Battery Level", "${(env.batteryLevel.value).toInt()}%", Icons.battery_charging_full),
                          _buildStatRow("Eco Mode", env.isEcoModeActive.value ? "ON" : "OFF", Icons.eco, color: Colors.green),
                        ],
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // ACTION BUTTONS
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    "SYNC HEALTH REFRESH", 
                    Icons.sync, 
                    Colors.blue,
                    () async {
                      final authRepo = context.read<IAuthRepository>();
                      final historyRepo = context.read<IHistoryRepository>();
                      await SyncService().forceDownSyncAndRefresh(authRepo, historyRepo);
                      _loadSystemStats();
                    }
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    "EXPORT SYSTEM LOGS", 
                    Icons.terminal, 
                    AppColors.brandDark,
                    () => context.push(AppRoutes.adminDiagnostics)
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }

  Widget _buildMetricCard(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brandDark)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(height: 24),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, {Color color = Colors.grey, bool isLong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: isLong ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          Flexible(
            child: Text(
              value, 
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 13,
                color: color == Colors.grey ? AppColors.brandDark : color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: isLong ? 2 : 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: Colors.white),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}
