import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'encryption_service.dart';

// Use conditional imports to avoid dart:io on Web
import 'notification_platform_helper.dart'
    if (dart.library.io) 'notification_platform_helper_native.dart'
    if (dart.library.html) 'notification_platform_helper_web.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final Completer<void> _initCompleter = Completer<void>();

  bool get _isSupported => kIsWeb || isNativeSupported;

  Future<void> init({bool showPermissionRequest = true}) async {
    // Only initialize on supported mobile platforms
    if (!_isSupported) {
      debugPrint("📢 NotificationService: Skipping init on this platform.");
      return;
    }

    // Initialize Timezone Database for Scheduling
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    } catch (e) {
      debugPrint("📢 NotificationService: Timezone initialization failed: $e");
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Windows Specific Init
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open Application');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      linux: initializationSettingsLinux,
    );

    try {
      // In background isolate, we only initialize the plugin shell to allow .show()
      // We skip permission checks and token cloud updates.
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );
    } catch (e) {
      debugPrint("📢 NotificationService: Plugin initialization failed: $e");
    } finally {
      if (!_initCompleter.isCompleted) _initCompleter.complete();
    }

    // Skip permission and Firebase flow if in background or explicit skip
    if (!showPermissionRequest) {
      debugPrint(
          "📢 NotificationService: Skipping UI flows (Background Mode).");
      return;
    }

    try {
      await _requestAndroidPermissions();
      await _createNotificationChannels();

      // --- NEW: Firebase Messaging Setup ---
      if (!kIsWeb && (isNativeAndroid || isNativeIOS)) {
        await _setupFirebaseMessaging();
      }
    } catch (e) {
      debugPrint("📢 NotificationService: Setup failed: $e");
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    // 1. Request Permission (iOS / Android 13+)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    debugPrint(
        "🔥 [Firebase] Permission status: ${settings.authorizationStatus}");

    // 2. Foreground Message Handling
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint(
          "🔥 [Firebase] Foreground Message: ${message.notification?.title}");

      if (message.notification != null) {
        final type = message.data['type'] ?? 'announcement';

        // Decrypt the message if it appears to be encrypted
        String displayBody = message.notification!.body ?? "";
        if (displayBody.contains(':')) {
          try {
            final encryption = EncryptionService();
            await encryption.init();
            displayBody = encryption.decryptData(displayBody);
          } catch (_) {}
        }

        switch (type) {
          case 'alert':
            showInstantNotification(
              id: message.hashCode,
              title: message.notification!.title ?? "Alert",
              body: displayBody,
            );
            break;
          case 'system_alert':
            showSystemAlertNotification(
              title: message.notification!.title ?? "System Alert",
              body: displayBody,
            );
            break;
          default:
            if (type == 'chat') {
              showChatNotification(
                senderName: 'Health Worker',
                message: displayBody,
              );
            } else {
              showAnnouncementNotification(
                title: message.notification!.title ?? "Announcement",
                body: displayBody,
              );
            }
        }
      }
    });

    // 3. Handle Token Refresh
    messaging.onTokenRefresh.listen((newToken) async {
      // Note: We'll need a way to get the current user ID here
      // if we want to update it automatically.
      debugPrint("🔥 [Firebase] Token Refreshed: $newToken");
    });
  }

  Future<void> _createNotificationChannels() async {
    if (!isNativeAndroid) return;

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      const List<AndroidNotificationChannel> channels = [
        AndroidNotificationChannel(
          'resident_alerts_channel',
          'Resident Alerts',
          description: 'Emergency and status alerts for residents',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        ),
        AndroidNotificationChannel(
          'announcements_channel',
          'Announcements',
          description: 'Official barangay announcements',
          importance: Importance.max, // Wakes phone
          playSound: true,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          'chat_messages_channel',
          'Direct Messages',
          description: 'Messages from Health Workers',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          'system_alerts_channel',
          'System Alerts',
          description: 'High-priority emergency broadcasting',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      ];

      for (var channel in channels) {
        await androidPlugin.createNotificationChannel(channel);
      }
    }
  }

  Future<bool> isNotificationsEnabled() async {
    if (kIsWeb) return true; // Web doesn't use SharedPreferences here yet
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notifications_enabled') ?? true;
    } catch (e) {
      // Background isolate might fail to get SharedPreferences in some environments
      return true;
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    if (!enabled) {
      await cancelAllReminders();
    }
  }

  Future<void> requestPermissions() async {
    if (!_isSupported) return;

    if (kIsWeb) {
      await requestWebPermission();
      return;
    }

    if (isNativeAndroid) {
      await _requestAndroidPermissions();
    } else if (isNativeIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  Future<void> _requestAndroidPermissions() async {
    try {
      final androidPlugin =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      }
    } catch (e) {
      debugPrint("⚠️ NotificationService: Android platform channel error: $e");
    }
  }

  void _onDidReceiveNotificationResponse(NotificationResponse details) {
    debugPrint("🔔 Notification Tapped: ${details.payload}");
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initCompleter.isCompleted) await _initCompleter.future;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'resident_alerts_channel',
      'Resident Alerts',
      channelDescription: 'Emergency and status alerts for residents',
      importance: Importance.max,
      priority: Priority.max, // URGENT
      showWhen: true,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true, // Wakes screen
      color: Color(0xFF1B5E20),
      ledColor: Color(0xFF1B5E20),
      ledOnMs: 1000,
      ledOffMs: 500,
      icon: 'ic_notification',
      category: AndroidNotificationCategory.alarm,
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: DarwinNotificationDetails());

    if (!_isSupported) return;
    if (await isNotificationsEnabled()) {
      if (kIsWeb) {
        showWebNotification(title, body, tag: 'alert');
        return;
      }

      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: 'instant_alert',
      );
    }
  }

  Future<void> scheduleDailyMedicationReminder({
    required int id,
    required String medicationName,
    required TimeOfDay time,
  }) async {
    if (!_initCompleter.isCompleted) await _initCompleter.future;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'medication_reminders_channel',
      'Medication Reminders',
      channelDescription: 'Daily pill reminders',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF2E7D32),
      category: AndroidNotificationCategory.reminder,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: DarwinNotificationDetails());

    if (!_isSupported) return;
    if (await isNotificationsEnabled()) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        "Medication Reminder",
        "Time to take your $medicationName.",
        scheduledDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'medication_pill',
      );
    }
  }

  Future<void> showAnnouncementNotification({
    required String title,
    required String body,
  }) async {
    if (!_initCompleter.isCompleted) await _initCompleter.future;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'announcements_channel',
      'Announcements',
      channelDescription: 'Official barangay announcements',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF2E7D32),
      icon: 'ic_notification',
      category: AndroidNotificationCategory.event,
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails, iOS: DarwinNotificationDetails());

    if (!_isSupported) return;
    if (await isNotificationsEnabled()) {
      if (kIsWeb) {
        showWebNotification(title, body, tag: 'announcement');
        return;
      }

      await flutterLocalNotificationsPlugin.show(
        999, // Static ID for announcements to overwrite previous
        title,
        body,
        platformDetails,
        payload: 'announcement',
      );
    }
  }

  Future<void> showSystemAlertNotification({
    required String title,
    required String body,
  }) async {
    if (!_initCompleter.isCompleted) await _initCompleter.future;

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'system_alerts_channel',
      'System Alerts',
      channelDescription: 'High-priority emergency broadcasting',
      importance: Importance.max,
      priority: Priority.max,
      color: Colors.red,
      icon: 'ic_notification',
      fullScreenIntent: true, // Stronger
      category: AndroidNotificationCategory.alarm,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      styleInformation: const BigTextStyleInformation(''),
    );

    final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails, iOS: const DarwinNotificationDetails());

    if (!_isSupported) return;
    if (await isNotificationsEnabled()) {
      if (kIsWeb) {
        showWebNotification(title, body, tag: 'system_alert');
        return;
      }

      await flutterLocalNotificationsPlugin.show(
        777, // Unique ID to keep alerts visible as a distinct stack
        title,
        body,
        platformDetails,
        payload: 'system_alert',
      );
    }
  }

  Future<void> showHardwareAlert({
    required String sensorName,
    required String status,
  }) async {
    if (!_initCompleter.isCompleted) await _initCompleter.future;

    final isError = status.toLowerCase() == 'error' ||
        status.toLowerCase() == 'disconnected';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'system_alerts_channel',
      'System Alerts',
      channelDescription: 'Hardware and system status alerts',
      importance: Importance.max,
      priority: Priority.high,
      color: isError ? Colors.red : Colors.orange,
      icon: 'ic_notification',
      category: AndroidNotificationCategory.status,
    );

    final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails, iOS: const DarwinNotificationDetails());

    if (!_isSupported) return;

    final title = "Hardware Alert: $sensorName";
    final body = "Sensor is now $status. Please check connections.";

    if (await isNotificationsEnabled()) {
      if (kIsWeb) {
        showWebNotification(title, body, tag: 'hardware');
        return;
      }

      await flutterLocalNotificationsPlugin.show(
        sensorName.hashCode,
        title,
        body,
        platformDetails,
        payload: 'hardware_alert',
      );
    }
  }

  Future<void> showChatNotification({
    required String senderName,
    required String message,
    int notificationId = 888,
  }) async {
    if (!_initCompleter.isCompleted) await _initCompleter.future;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'chat_messages_channel',
      'Direct Messages',
      channelDescription: 'Messages from Health Workers',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF2E7D32),
      styleInformation: BigTextStyleInformation(''),
      icon: 'ic_notification',
      category: AndroidNotificationCategory.message,
    );

    const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails, iOS: DarwinNotificationDetails());

    if (!_isSupported) return;
    if (await isNotificationsEnabled()) {
      if (kIsWeb) {
        showWebNotification("New Message from $senderName", message,
            tag: 'chat');
        return;
      }

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        "New Message from $senderName",
        message,
        platformDetails,
        payload: 'chat',
      );
    }
  }

  Future<void> cancelAllReminders() async {
    if (!_isSupported) return;
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Returns the Firebase Messaging token for this device.
  Future<String?> getDeviceToken() async {
    if (kIsWeb) return null;
    if (!isNativeAndroid && !isNativeIOS) return null;

    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint("⚠️ NotificationService: Failed to get FCM token: $e");
      return null;
    }
  }

  /// REST & PUSH TOKEN MANAGEMENT

  /// Updates the device token in Supabase for the current user.
  /// This ensures push notifications are routed to THIS device for THIS user.
  Future<void> updateDeviceToken(String userId, String token) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('patients')
          .update({'device_token': token}).eq('id', userId);

      debugPrint(
          "📡 NotificationService: Device token updated in cloud for $userId");
    } catch (e) {
      debugPrint("⚠️ NotificationService: Failed to update device token: $e");
    }
  }

  /// Clears the device token from Supabase for the current user.
  /// CRITICAL: Prevents User B from receiving User A's notifications on the same device.
  Future<void> clearDeviceToken(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('patients')
          .update({'device_token': null}).eq('id', userId);

      debugPrint(
          "📡 NotificationService: Device token cleared in cloud for $userId");
    } catch (e) {
      debugPrint("⚠️ NotificationService: Failed to clear device token: $e");
    }
  }
}
