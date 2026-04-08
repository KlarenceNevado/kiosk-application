import 'dart:async';
import 'package:flutter/foundation.dart';
import '../security/notification_service.dart';
import '../database/sync_service.dart';

class VitalsListenerService {
  static final VitalsListenerService _instance =
      VitalsListenerService._internal();
  factory VitalsListenerService() => _instance;
  VitalsListenerService._internal();

  StreamSubscription? _syncSubscription;
  List<String> _monitoredUserIds = [];

  void startListening({
    required List<String> familyIds,
  }) {
    if (_syncSubscription != null) return;

    _monitoredUserIds = familyIds;

    debugPrint(
        "📡 Starting Vitals Listener for Family [${familyIds.join(', ')}] (via SyncService)...");

    _syncSubscription = SyncService().newVitalStream.listen((data) {
      final String recordUserId = data['userId'] ?? data['user_id'] ?? '';

      if (_monitoredUserIds.contains(recordUserId)) {
        debugPrint(
            "🆕 New Cloud Vital detected for family member: $recordUserId");

        final String status = data['status'] ?? 'pending';
        final String title = status == 'verified'
            ? "Health Check Verified ✅"
            : "New Health Check Recorded";

        NotificationService().showInstantNotification(
          id: data['id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
          title: title,
          body:
              "A new health reading has been processed for your family account.",
        );
      }
    });

    // We also listen for status updates (handled by the general vitals stream in SyncService)
    // For now, newVitalStream covers new records.
  }

  void stopListening() {
    _syncSubscription?.cancel();
    _syncSubscription = null;
    _monitoredUserIds = [];
  }
}
