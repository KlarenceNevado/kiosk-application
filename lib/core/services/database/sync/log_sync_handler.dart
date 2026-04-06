import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sync_handler.dart';
import '../../../models/system_log_model.dart';
import 'package:kiosk_application/core/services/security/security_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogSyncHandler extends SyncHandler {
  LogSyncHandler(super.supabase, [super.db]);

  static bool _hasWarnedRLS = false;
  static bool _isPushing = false;

  @override
  Future<void> push() async {
    if (_isPushing) return;
    
    // Check persistence to avoid showing the big box every restart
    if (!_hasWarnedRLS) {
      final prefs = await SharedPreferences.getInstance();
      _hasWarnedRLS = prefs.getBool('has_shown_rls_warning') ?? false;
    }
    
    if (_hasWarnedRLS) {
       // Subtle notice if already warned in previous sessions
       return; 
    }
    
    _isPushing = true;
    try {
      final unsyncedLogs = await dbHelper.systemDao.getUnsyncedSystemLogs();
      if (unsyncedLogs.isEmpty) {
        _isPushing = false;
        return;
      }

      SecurityLogger.info("Sync: Pushing ${unsyncedLogs.length} system logs to Supabase...");

      for (final log in unsyncedLogs) {
        try {
          await _pushSingleLog(log);
          await dbHelper.systemDao.markSystemLogAsSynced(log.id);
        } catch (e) {
          if (e.toString().contains('42501')) {
            _hasWarnedRLS = true; 
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('has_shown_rls_warning', true);
            
            SecurityLogger.warning("Sync: Log push rejected by Supabase RLS Policy. (Unauthorized 42501)");
            debugPrint("\n${'=' * 60}");
            debugPrint("💡 [RPi Sync Fix Required]");
            debugPrint("The 'system_logs' table is missing an INSERT policy for 'anon'.");
            debugPrint("To fix this and enable cloud logging, run the provided SQL script:");
            debugPrint("file:///C:/Users/Klarence%20Nevado/.gemini/antigravity/brain/1d6893b4-801b-4791-9c58-87d51912d66d/supabase_rls_fix.sql");
            debugPrint("${'=' * 60}\n");
            _isPushing = false;
            return; 
          } else {
            SecurityLogger.error("Sync: Failed to push log ${log.id}: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("❌ LogSyncHandler: Critical Push Error: $e");
    } finally {
      _isPushing = false;
    }
  }

  Future<void> _pushSingleLog(SystemLog log) async {
    final Map<String, dynamic> data = log.toMap();
    // Supabase specific mapping: exclude local sync flag
    data.remove('is_synced');
    
    // Pass 'user_id' as-is (Text compatibility in Supabase allows for UUID, local_, or 'SYSTEM')
    if (data['user_id'] != null) {
      data['user_id'] = data['user_id'].toString();
    }
    
    // RLS will handle permission check (Allow insert for authenticated/anon)
    await supabase.from('system_logs').upsert(data);
  }

  @override
  Future<void> pull() async {
    // Audit logs are append-only from the device. 
    // Pulling is reserved for Admins in the Command Center, 
    // which they do directly from Supabase.
    return;
  }
}
