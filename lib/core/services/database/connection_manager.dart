import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ConnectionStatus { online, offline, checking }

class ConnectionManager extends ChangeNotifier {
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  ConnectionStatus _currentStatus = ConnectionStatus.checking;
  ConnectionStatus get currentStatus => _currentStatus;
  
  bool get isOnline => _currentStatus == ConnectionStatus.online;

  Timer? _checkTimer;
  bool _isChecking = false;

  void startMonitoring() {
    debugPrint("🌐 ConnectionManager: Starting monitoring...");
    
    // Initial check
    checkStatus();

    // Listen for platform-level changes
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      debugPrint("🌐 Connectivity changed: $result");
      checkStatus();
    });

    // Heartbeat check for Windows/Restricted platforms
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) => checkStatus());
  }

  /// Explicitly re-check connectivity (used by UI Retry buttons)
  Future<void> retryConnection() async {
    debugPrint("🌐 ConnectionManager: Manual retry requested...");
    await checkStatus();
  }

  Future<void> checkStatus() async {
    if (_isChecking) return;
    _isChecking = true;

    ConnectionStatus newStatus = ConnectionStatus.offline;

    try {
      final result = await Connectivity().checkConnectivity();
      
      if (result == ConnectivityResult.none) {
        newStatus = ConnectionStatus.offline;
      } else if (kIsWeb) {
        // Browsers block cross-domain pings (CORS). Trust the navigator.onLine reporting.
        newStatus = ConnectionStatus.online;
      } else {
        // Native platforms: Verify actual reachability
        try {
          final response = await http
              .head(Uri.parse('https://www.google.com'))
              .timeout(const Duration(seconds: 3));
          
          if (response.statusCode >= 200 && response.statusCode < 400) {
            newStatus = ConnectionStatus.online;
          } else {
            newStatus = ConnectionStatus.offline;
          }
        } catch (_) {
          newStatus = ConnectionStatus.offline;
        }
      }
    } catch (e) {
      debugPrint("⚠️ ConnectionManager Check Error: $e");
      newStatus = ConnectionStatus.offline;
    }

    if (newStatus != _currentStatus) {
      debugPrint("🌐 ConnectionManager: Status changed to $newStatus");
      _currentStatus = newStatus;
      _statusController.add(newStatus);
      notifyListeners(); // Alert the UI
    }
    
    _isChecking = false;
  }

  void stopMonitoring() {
    _checkTimer?.cancel();
  }
}
