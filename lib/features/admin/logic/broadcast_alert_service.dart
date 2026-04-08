import 'package:flutter/foundation.dart';
import '../../auth/models/user_model.dart';
import '../../../core/services/database/sync_service.dart';

class BroadcastAlertService {
  static final BroadcastAlertService _instance = BroadcastAlertService._internal();
  factory BroadcastAlertService() => _instance;
  BroadcastAlertService._internal();

  /// Sends a health alert to a specific user via the system alert channel.
  Future<bool> sendPersonalAlert({
    required User user,
    required String message,
  }) async {
    try {
      debugPrint("📢 [BroadcastAlert] Sending alert to ${user.fullName}: $message");
      
      await SyncService().pushAlert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: message,
        targetGroup: 'PERSONAL',
        isEmergency: true,
        timestamp: DateTime.now(),
        isActive: true,
        targetUserId: user.id,
      );

      return true;
    } catch (e) {
      debugPrint("❌ [BroadcastAlert] Error sending alert: $e");
      return false;
    }
  }

  /// Broadcasts an alert to a specific target group (e.g. SENIORS).
  Future<bool> broadcastGroupAlert({
    required String targetGroup, // 'ALL', 'SENIORS', 'CHILDREN'
    required String message,
  }) async {
    try {
      debugPrint("📢 [BroadcastAlert] Broadcasting to $targetGroup: $message");
      
      await SyncService().pushAlert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: message,
        targetGroup: targetGroup,
        isEmergency: false,
        timestamp: DateTime.now(),
        isActive: true,
      );

      return true;
    } catch (e) {
      debugPrint("❌ [BroadcastAlert] Error broadcasting: $e");
      return false;
    }
  }
}

