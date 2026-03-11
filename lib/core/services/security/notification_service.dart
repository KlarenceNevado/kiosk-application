import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Only initialize on supported mobile platforms
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint("📢 NotificationService: Skipping init on this platform.");
      return;
    }

    // Initialize Timezone Database for Scheduling
    tz.initializeTimeZones();
    // Use a try-catch for location setting as it might fail in some environments
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    } catch (e) {
      debugPrint("Timezone initialization failed: $e");
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

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // Request Permissions on Android 13+
    _requestAndroidPermissions();
  }

  void _requestAndroidPermissions() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
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
      showWhen: false,
      color: Color(0xFF2E7D32),
      icon: 'ic_notification',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: 'instant_alert',
    );
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
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

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
    );

    const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails, iOS: DarwinNotificationDetails());

    await flutterLocalNotificationsPlugin.show(
      999, // Static ID for announcements to overwrite previous
      title,
      body,
      platformDetails,
      payload: 'announcement',
    );
  }

  Future<void> showSystemAlertNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'system_alerts_channel',
      'System Alerts',
      channelDescription: 'High-priority emergency broadcasting',
      importance: Importance.max,
      priority: Priority.max,
      color: Colors.red,
      icon: 'ic_notification',
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails, iOS: DarwinNotificationDetails());

    await flutterLocalNotificationsPlugin.show(
      777, // Unique ID to keep alerts visible as a distinct stack
      title,
      body,
      platformDetails,
      payload: 'system_alert',
    );
  }

  Future<void> showChatNotification({
    required String senderName,
    required String message,
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
    );

    const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails, iOS: DarwinNotificationDetails());

    await flutterLocalNotificationsPlugin.show(
      888, // Static ID for chat
      "New Message from $senderName",
      message,
      platformDetails,
      payload: 'chat',
    );
  }

  Future<void> cancelAllReminders() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
