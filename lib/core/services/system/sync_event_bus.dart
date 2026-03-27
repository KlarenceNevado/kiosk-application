import 'dart:async';

/// A pure Dart event bus strictly used for cross-platform UI synchronization updates.
///
/// Native UI screens listen to these pure streams instead of importing `SyncService`,
/// which strictly prevents `dart:io` and `sqflite` plugins from unintentionally contaminating the Web PWA compilation.
class SyncEventBus {
  static final SyncEventBus instance = SyncEventBus._internal();
  SyncEventBus._internal();

  final _vitalsController = StreamController<void>.broadcast();
  final _announcementController = StreamController<void>.broadcast();
  final _newAnnouncementController = StreamController<Map<String, dynamic>>.broadcast();
  final _alertController = StreamController<void>.broadcast();
  final _newAlertController = StreamController<Map<String, dynamic>>.broadcast();
  final _patientController = StreamController<void>.broadcast();
  final _scheduleController = StreamController<void>.broadcast();

  // Public streams for Native UI to listen to
  Stream<void> get vitalsStream => _vitalsController.stream;
  Stream<void> get announcementStream => _announcementController.stream;
  Stream<Map<String, dynamic>> get newAnnouncementStream => _newAnnouncementController.stream;
  Stream<void> get alertStream => _alertController.stream;
  Stream<Map<String, dynamic>> get newAlertStream => _newAlertController.stream;
  Stream<void> get patientStream => _patientController.stream;
  Stream<void> get scheduleStream => _scheduleController.stream;

  // Triggers fired silently by Native Background Sync or Web Realtime channels
  void triggerVitalsUpdate() => _vitalsController.add(null);
  void triggerAnnouncementUpdate() => _announcementController.add(null);
  void triggerNewAnnouncement(Map<String, dynamic> data) => _newAnnouncementController.add(data);
  void triggerAlertUpdate() => _alertController.add(null);
  void triggerNewAlert(Map<String, dynamic> data) => _newAlertController.add(data);
  void triggerPatientUpdate() => _patientController.add(null);
  void triggerScheduleUpdate() => _scheduleController.add(null);
  
  void dispose() {
    _vitalsController.close();
    _announcementController.close();
    _newAnnouncementController.close();
    _alertController.close();
    _newAlertController.close();
    _patientController.close();
    _scheduleController.close();
  }
}
