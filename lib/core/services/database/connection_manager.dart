import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ConnectionStatus { online, offline, checking }

class ConnectionManager {
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  ConnectionStatus _currentStatus = ConnectionStatus.checking;
  ConnectionStatus get currentStatus => _currentStatus;

  Timer? _checkTimer;
  bool _isChecking = false;

  void startMonitoring() {
    debugPrint("🌐 ConnectionManager: Starting monitoring...");
    
    // Initial check
    checkStatus();

    // Listen for platform-level changes (Mobile/Web support)
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      debugPrint("🌐 Connectivity changed: $result");
      checkStatus();
    });

    // Heartbeat check for Windows/Restricted platforms
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) => checkStatus());
  }

  Future<void> checkStatus() async {
    if (_isChecking) return;
    _isChecking = true;

    ConnectionStatus newStatus = ConnectionStatus.offline;

    try {
      // 1. Check connectivity_plus first
      final result = await Connectivity().checkConnectivity();
      
      if (result == ConnectivityResult.none) {
        newStatus = ConnectionStatus.offline;
      } else {
        // 2. Verified Internet Check (Avoid "Connected but no Internet")
        // We ping a reliable source (Google DNS or Supabase Health - here we use a simple reliable ping)
        try {
          // Timeout quickly to prevent UI lag
          final response = await http
              .head(Uri.parse('https://www.google.com'))
              .timeout(const Duration(seconds: 3));
          
          if (response.statusCode >= 200 && response.statusCode < 400) {
            newStatus = ConnectionStatus.online;
          } else {
            newStatus = ConnectionStatus.offline;
          }
        } catch (_) {
          // If DNS fails or host unreachable
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
    }
    
    _isChecking = false;
  }

  void stopMonitoring() {
    _checkTimer?.cancel();
  }
}
