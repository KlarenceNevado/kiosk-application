import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../security/notification_service.dart';
import '../database/database_helper.dart';
import '../database/sync/system_sync_handler.dart';

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

    // 1. Initialize Supabase and Database in Background Isolate
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.database; // Ensure local DB is ready

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

    // 2. Initialize Notifications (Skip permission requests in background isolate)
    await NotificationService().init(showPermissionRequest: false);

    // 3. Set up Sync Handler for Background
    final systemHandler = SystemSyncHandler(Supabase.instance.client);

    // 4. Set up Realtime Listeners
    final supabase = Supabase.instance.client;

    // Listen to Announcements
    supabase.channel('bg_announcements')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          callback: (payload) async {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final id = payload.oldRecord['id']?.toString();
              if (id != null) {
                await dbHelper.systemDao.hardDeleteAnnouncement(id);
                debugPrint("🧹 Background: Removed deleted announcement $id");
              }
              return;
            }

            final row = payload.newRecord;
            if (row.isNotEmpty) {
              await dbHelper.systemDao.insertAnnouncement({
                ...row,
                'is_synced': 1,
              });
              
              if (payload.eventType == PostgresChangeEvent.insert) {
                _showAnnouncementNotification(row);
              }
            }
          },
        )
        .subscribe();

    // Listen to Alerts
    supabase.channel('bg_alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alerts',
          callback: (payload) async {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final id = payload.oldRecord['id']?.toString();
              if (id != null) {
                await dbHelper.systemDao.hardDeleteAlert(id);
                debugPrint("🧹 Background: Removed deleted alert $id");
              }
              return;
            }

            if (payload.eventType == PostgresChangeEvent.insert) {
              final row = payload.newRecord;
              if (row.isNotEmpty) {
                 await dbHelper.systemDao.insertAlert({
                   ...row,
                   'is_synced': 1,
                 });
                 
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
          callback: (payload) async {
             if (payload.eventType == PostgresChangeEvent.delete) {
               final id = payload.oldRecord['id']?.toString();
               if (id != null) {
                 await dbHelper.systemDao.hardDeleteSchedule(id);
               }
             } else if (payload.newRecord.isNotEmpty) {
               await dbHelper.systemDao.insertSchedule({
                 ...payload.newRecord,
                 'is_synced': 1,
               });
             }
             debugPrint("📅 Background: Schedule change synchronized");
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

    // 5. Periodic Heartbeat Pull (Parity Sync)
    // Runs every 15 minutes to catch missed realtime events
    Timer.periodic(const Duration(minutes: 15), (timer) async {
       debugPrint("🔄 Background: Heartbeat Sync Starting...");
       try {
         await systemHandler.pullAnnouncements();
         await systemHandler.pullAlerts();
       } catch (e) {
         debugPrint("⚠️ Background Heartbeat Failed: $e");
       }
    });

    debugPrint("🔔 [BackgroundService] Sync Isolate Ready.");
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
