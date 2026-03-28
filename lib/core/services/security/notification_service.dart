import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

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

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    try {
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );
    } catch (e) {
      debugPrint("📢 NotificationService: Plugin initialization failed: $e");
    }

    // Request Permissions on Android 13+ ONLY if specified (Main Isolate)
    try {
      if (showPermissionRequest) {
        await _requestAndroidPermissions();
      }
      await _createNotificationChannels(); 
    } catch (e) {
      debugPrint("📢 NotificationService: Android setup failed: $e");
    }
  }

  Future<void> _createNotificationChannels() async {
    if (!isNativeAndroid) return;

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      const List<AndroidNotificationChannel> channels = [
        AndroidNotificationChannel(
          'patient_alerts_channel',
          'Patient Alerts',
          description: 'Emergency and status alerts for patients',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          'announcements_channel',
          'Announcements',
          description: 'Official barangay announcements',
          importance: Importance.max,
          playSound: true,
        ),
        AndroidNotificationChannel(
          'chat_messages_channel',
          'Direct Messages',
          description: 'Messages from Health Workers',
          importance: Importance.max,
          playSound: true,
        ),
        AndroidNotificationChannel(
          'system_alerts_channel',
          'System Alerts',
          description: 'High-priority emergency broadcasting',
          importance: Importance.max,
          playSound: true,
        ),
      ];

      for (var channel in channels) {
        await androidPlugin.createNotificationChannel(channel);
      }
    }
  }

  Future<bool> isNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
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
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  Future<void> _requestAndroidPermissions() async {
    try {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
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
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'patient_alerts_channel',
      'Patient Alerts',
      channelDescription: 'Emergency and status alerts for patients',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      color: Color(0xFF1B5E20), // Darker Green
      ledColor: Color(0xFF1B5E20),
      ledOnMs: 1000,
      ledOffMs: 500,
      icon: 'ic_notification',
      category: AndroidNotificationCategory.status,
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics, iOS: DarwinNotificationDetails());

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

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics, iOS: DarwinNotificationDetails());

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

  Future<void> showChatNotification({
    required String senderName,
    required String message,
    int notificationId = 888,
  }) async {
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
        showWebNotification("New Message from $senderName", message, tag: 'chat');
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
}
