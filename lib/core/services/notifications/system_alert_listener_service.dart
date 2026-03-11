import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../security/notification_service.dart';

class SystemAlertListenerService {
  static final SystemAlertListenerService _instance =
      SystemAlertListenerService._internal();
  factory SystemAlertListenerService() => _instance;
  SystemAlertListenerService._internal();

  RealtimeChannel? _subscription;
  String? _currentUserRoleOrGroup;
  String? _currentUserSitio;

  /// Starts listening to the `alerts` table.
  /// Needs contextual info to know if an alert applies to this device.
  void startListening({
    required String userRole, // 'patient', 'bhw', 'superadmin', etc.
    String? sitio,
  }) {
    if (_subscription != null) return;

    _currentUserRoleOrGroup = userRole;
    _currentUserSitio = sitio;

    debugPrint(
        "📡 Starting System Alert Listener for [$_currentUserRoleOrGroup]...");

    _subscription = Supabase.instance.client
        .channel('public:system_alerts_push')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'alerts',
          callback: (payload) {
            final data = payload.newRecord;
            final bool isActive = data['is_active'] ?? true;
            if (!isActive) return; // Ignore archived alerts

            final String targetGroup =
                (data['target_group'] ?? '').toString().toUpperCase();
            final String message =
                data['message'] ?? 'Emergency Alert Received';

            // Determine if the current user qualifies for this alert
            bool shouldNotify = false;

            if (targetGroup == 'BROADCAST_ALL') {
              shouldNotify = true;
            } else if (targetGroup == 'ALL_BHWS' &&
                _currentUserRoleOrGroup != 'patient') {
              shouldNotify = true;
            } else if (targetGroup == 'PATIENTS' &&
                _currentUserRoleOrGroup == 'patient') {
              shouldNotify = true;
            } else if (targetGroup == 'SITIO_2' &&
                _currentUserSitio?.toUpperCase() == 'SITIO 2') {
              shouldNotify = true;
            } else if (targetGroup == 'LEADS' &&
                (_currentUserRoleOrGroup == 'superadmin' ||
                    _currentUserRoleOrGroup == 'coordinator')) {
              shouldNotify = true;
            }

            if (shouldNotify) {
              NotificationService().showSystemAlertNotification(
                title: 'CRITICAL SYSTEM ALERT',
                body: message,
              );
            }
          },
        )
        .subscribe();
  }

  void stopListening() {
    _subscription?.unsubscribe();
    _subscription = null;
    _currentUserRoleOrGroup = null;
    _currentUserSitio = null;
  }
}
