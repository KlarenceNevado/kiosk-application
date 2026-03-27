import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../security/notification_service.dart';

@pragma('vm:entry-point')
class BackgroundServiceHelper {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'system_alerts_channel', // High priority
        initialNotificationTitle: 'Kiosk Sync Active',
        initialNotificationContent: 'Monitoring for alerts & announcements...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    await service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // 1. Initialize Supabase in Background Isolate
    try {
      await dotenv.load(fileName: "assets/.env");
      final url = dotenv.env['SUPABASE_URL'] ?? '';
      final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
      
      if (url.isNotEmpty && key.isNotEmpty) {
        await Supabase.initialize(url: url, anonKey: key);
        debugPrint("🔔 [BackgroundService] Supabase Initialized.");
      }
    } catch (e) {
      debugPrint("❌ [BackgroundService] Supabase Init Failed: $e");
      return;
    }

    // 2. Initialize Notifications
    await NotificationService().init();

    // 3. Set up Realtime Listeners
    final supabase = Supabase.instance.client;

    // Listen to Announcements (All changes for sync, Notify on Insert/Active Update)
    supabase.channel('bg_announcements')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          callback: (payload) async {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final id = payload.oldRecord['id']?.toString();
              if (id != null) {
                // Background Isolate DAO shared connection
                // (Note: systemDao needs to be re-initialized or accessed via helper)
                // Actually we can just use Supabase direct or assume push/pull logic.
                // But let's just use the Payload to update local DB if possible.
              }
              return;
            }

            final row = payload.newRecord;
            if (row.isNotEmpty) {
              // Standard auto-sync into local DB even in background
              // Note: We don't have DatabaseHelper instance in background isolate easily 
              // unless we init it here.
              if (payload.eventType == PostgresChangeEvent.insert) {
                _showAnnouncementNotification(row);
              }
            }
          },
        )
        .subscribe();

    // Listen to Alerts (All changes for sync, Notify on Insert)
    supabase.channel('bg_alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alerts',
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.insert) {
              final row = payload.newRecord;
              if (row.isNotEmpty) {
                 NotificationService().showInstantNotification(
                   id: 777,
                   title: "🚨 URGENT ALERT",
                   body: row['message'] ?? "New alert received.",
                 );
              }
            }
          },
        )
        .subscribe();

    // Listen to Schedules
    supabase.channel('bg_schedules')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'schedules',
          callback: (payload) {
             debugPrint("📅 Background: Schedule change detected");
          },
        )
        .subscribe();

    // Listen to Vitals (For High Risk notifications)
    supabase.channel('bg_vitals')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'vitals',
          callback: (payload) {
             final row = payload.newRecord;
             if (row.isNotEmpty) {
               final status = row['status']?.toString().toUpperCase() ?? 'NORMAL';
               if (status.contains('HIGH') || status.contains('EMERGENCY')) {
                 NotificationService().showInstantNotification(
                   id: 999,
                   title: "🏥 CRITICAL HEALTH UPDATE",
                   body: "A high-risk health screening has been recorded. Please check reports.",
                 );
               }
             }
          },
        )
        .subscribe();

    debugPrint("🔔 [BackgroundService] Listeners Active.");
  }

  static void _showAnnouncementNotification(Map<String, dynamic> row) {
    final target = row['target_group']?.toString().toUpperCase() ?? 'ALL';
    final title = row['title'] ?? "New Announcement";
    final body = row['content'] ?? "Tap to view details";

    if (target == 'BROADCAST_ALL') {
      NotificationService().showSystemAlertNotification(
        title: "🚨 URGENT: $title",
        body: body,
      );
    } else {
      NotificationService().showAnnouncementNotification(
        title: title,
        body: body,
      );
    }
  }
}
