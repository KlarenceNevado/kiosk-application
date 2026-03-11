import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../security/notification_service.dart';

class AnnouncementListenerService {
  static final AnnouncementListenerService _instance =
      AnnouncementListenerService._internal();
  factory AnnouncementListenerService() => _instance;
  AnnouncementListenerService._internal();

  RealtimeChannel? _subscription;

  void startListening() {
    if (_subscription != null) return;

    debugPrint("📡 Starting Global Announcement Listener...");

    _subscription = Supabase.instance.client
        .channel('public:global_announcements')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'announcements',
          callback: (payload) {
            final data = payload.newRecord;
            final String title = data['title'] ?? 'New Announcement';
            final String body =
                data['content'] ?? 'Check your inbox for details.';

            // Trigger local notification
            NotificationService().showAnnouncementNotification(
              title: title,
              body: body,
            );
          },
        )
        .subscribe();
  }

  void stopListening() {
    _subscription?.unsubscribe();
    _subscription = null;
  }
}
