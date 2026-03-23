import 'dart:async';
import 'package:flutter/foundation.dart';
import '../security/notification_service.dart';
import '../database/sync_service.dart';

class AnnouncementListenerService {
  static final AnnouncementListenerService _instance =
      AnnouncementListenerService._internal();
  factory AnnouncementListenerService() => _instance;
  AnnouncementListenerService._internal();

  StreamSubscription? _syncSubscription;

  void startListening() {
    if (_syncSubscription != null) return;

    debugPrint("📡 Starting Global Announcement Listener (via SyncService)...");

    _syncSubscription = SyncService().newAnnouncementStream.listen((data) {
      final String title = data['title'] ?? 'New Announcement';
      final String body = data['content'] ?? 'Check your inbox for details.';

      // Trigger local notification (Mobile/Tablet only handled by NotificationService)
      NotificationService().showAnnouncementNotification(
        title: title,
        body: body,
      );
    });
  }

  void stopListening() {
    _syncSubscription?.cancel();
    _syncSubscription = null;
  }
}
