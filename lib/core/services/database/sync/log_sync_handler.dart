import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sync_handler.dart';
import '../../../models/system_log_model.dart';
import 'package:kiosk_application/core/services/security/security_logger.dart';

class LogSyncHandler extends SyncHandler {
  LogSyncHandler(super.supabase, [super.db]);

  @override
  Future<void> push() async {
    try {
      final unsyncedLogs = await dbHelper.systemDao.getUnsyncedSystemLogs();
      if (unsyncedLogs.isEmpty) return;

      SecurityLogger.info("Sync: Pushing ${unsyncedLogs.length} system logs to Supabase...");

      for (final log in unsyncedLogs) {
        try {
          await _pushSingleLog(log);
          await dbHelper.systemDao.markSystemLogAsSynced(log.id);
        } catch (e) {
          SecurityLogger.error("Sync: Failed to push log ${log.id}: $e");
          // Don't block the whole loop for one log failure
        }
      }
    } catch (e) {
      debugPrint("❌ LogSyncHandler: Critical Push Error: $e");
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
