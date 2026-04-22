import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../sensor_service_interface.dart';

/// specialized driver for the ESP32 Hub.
/// It reads JSON data and emits events for multiple sensor types.
class SensorHubService implements ISensorService {
  @override
  final SensorType
      type; // Principal type (e.g., weight) for ISensorService compatibility
  final String portName;
  final int baudRate;

  final _dataController = StreamController<dynamic>.broadcast();
  final _secondaryDataController = StreamController<dynamic>.broadcast();
  final _batteryDataController = StreamController<double>.broadcast();
  final _statusController = StreamController<SensorStatus>.broadcast();
  final _rawController = StreamController<List<int>>.broadcast();

  SensorStatus _status = SensorStatus.disconnected;
  SerialPort? _port;
  SerialPortReader? _reader;
  DateTime? _lastDataReceived;
  Timer? _watchdogTimer;

  SensorHubService({
    required this.type,
    required this.portName,
    this.baudRate = 115200, // Higher baud for hub
  });

  @override
  Stream<dynamic> get dataStream => _dataController.stream;

  @override
  Stream<List<int>> get rawStream => _rawController.stream;

  Stream<dynamic> get secondaryDataStream => _secondaryDataController.stream;

  Stream<double> get batteryStream => _batteryDataController.stream;

  @override
  Stream<SensorStatus> get statusStream => _statusController.stream;

  @override
  SensorStatus get currentStatus => _status;

  @override
  void startReading() async {
    if (_status == SensorStatus.reading || _status == SensorStatus.connecting) {
      return;
    }
    _updateStatus(SensorStatus.connecting);

    try {
      if (!SerialPort.availablePorts.contains(portName)) {
        _updateStatus(SensorStatus.disconnected);
        return;
      }

      _port = SerialPort(portName);
      if (!_port!.openReadWrite()) throw Exception("Could not open Hub port");

      _port!.config = SerialPortConfig()..baudRate = baudRate;
      _updateStatus(SensorStatus.reading);
      _startWatchdog();

      _reader = SerialPortReader(_port!);
      _reader!.stream.listen(_handleRawData);
    } catch (e) {
      _updateStatus(SensorStatus.error);
    }
  }

  @override
  void stopReading() {
    _watchdogTimer?.cancel();
    _reader?.close();
    _port?.close();
    _port = null;
    _updateStatus(SensorStatus.disconnected);
  }

  void _updateStatus(SensorStatus status) {
    _status = status;
    _statusController.add(status);
  }

  String _stringBuffer = "";

  void _handleRawData(Uint8List bytes) {
    _lastDataReceived = DateTime.now(); // Watchdog handshake
    _rawController.add(bytes); 
    
    if (kDebugMode) {
      debugPrint("📥 [SensorHubService] Incoming: ${bytes.length} bytes");
    }

    try {
      final String decoded = utf8.decode(bytes);
      _stringBuffer += decoded;
      
      if (_stringBuffer.contains('\n')) {
        final List<String> lines = const LineSplitter().convert(_stringBuffer);
        
        if (!_stringBuffer.endsWith('\n')) {
          _stringBuffer = lines.removeLast();
        } else {
          _stringBuffer = "";
        }

        for (final line in lines) {
          _parseLine(line);
        }
      }
    } catch (e) {
      debugPrint("⚠️ [SensorHubService] UTF8 Decode Error: $e");
      _stringBuffer = "";
    }
  }

  void _parseLine(String line) {
    if (line.trim().isEmpty) return;
    
    debugPrint("📡 [SensorHubService] Raw Line: $line");

    // 1. Attempt JSON Parsing (New Robust Heartbeat)
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic>) {
        final device = decoded['device'];
        
        if (device == 'esp32') {
          // Weight (HX711)
          if (decoded.containsKey('hx711_val')) {
            final val = double.tryParse(decoded['hx711_val'].toString()) ?? 0.0;
            _dataController.add(val);
          }
          
          // Temperature (MLX)
          if (decoded.containsKey('mlx_val')) {
            final val = double.tryParse(decoded['mlx_val'].toString());
            if (val != null) {
              _secondaryDataController.add({'type': 'temp', 'value': val});
            }
          }

          // Status Reporting (Optional: broadcast to a notification system if status is ERROR)
          final hxStatus = decoded['hx711_status'];
          final mlxStatus = decoded['mlx_status'];
          if (hxStatus == 'ERROR' || mlxStatus == 'ERROR') {
             _updateStatus(SensorStatus.error);
          } else if (_status == SensorStatus.error) {
             _updateStatus(SensorStatus.reading);
          }
          
          return; // Early exit on successful structured parse
        }

        // Legacy/Fallback parsing for other types
        final type = decoded['type'];
        final value = decoded['value'];

        if (type == 'weight') {
          _dataController.add(double.tryParse(value.toString()) ?? 0.0);
        } else if (type == 'temp' || type == 'thermometer') {
          _secondaryDataController.add({'type': 'temp', 'value': double.tryParse(value.toString())});
        }
        return; 
      }
    } catch (_) {
      // Not JSON, fall back to comma-separated parsing
    }

    // 2. Comma-Separated String Parsing (Alternate Protocol: T:36.5,W:0.0,H:160)
    try {
      final segments = line.split(',');
      for (final segment in segments) {
        final clean = segment.trim();
        if (clean.startsWith('T:')) {
          final val = double.tryParse(clean.substring(2));
          if (val != null) _secondaryDataController.add({'type': 'temp', 'value': val});
        } else if (clean.startsWith('W:')) {
          final val = double.tryParse(clean.substring(2));
          if (val != null) _dataController.add(val);
        } else if (clean.startsWith('B:')) {
          final val = double.tryParse(clean.substring(2));
          if (val != null) _batteryDataController.add(val);
        }
      }
    } catch (e) {
      debugPrint("⚠️ [SensorHubService] Parse Error on line '$line': $e");
    }
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _lastDataReceived = DateTime.now();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_status != SensorStatus.reading) {
        timer.cancel();
        return;
      }

      final lastSeen = _lastDataReceived;
      if (lastSeen != null) {
        final idleTime = DateTime.now().difference(lastSeen).inSeconds;
        if (idleTime > 10) {
          debugPrint("⚠️ [HubWatchdog] No data from ESP32 Hub for 10s. Reconnecting...");
          _reconnect();
        }
      }
    });
  }

  void _reconnect() async {
    _reader?.close();
    _port?.close();
    await Future.delayed(const Duration(seconds: 1));
    startReading();
  }

  /// Sends a handshake/status query to the hub
  Future<void> handshake() async {
    await writeString(jsonEncode({'cmd': 'handshake'}));
    await writeString('HANDSHAKE\n'); // Send both formats
  }

  @override
  Future<void> sendCommand(Uint8List command) async {
    if (_port == null || _status != SensorStatus.reading) {
      debugPrint(
          "⚠️ [SensorHubService] Cannot send command to Hub: Port not open.");
      return;
    }
    try {
      _port!.write(command);
    } catch (e) {
      debugPrint("❌ [SensorHubService] Error sending command to Hub: $e");
    }
  }

  @override
  Future<void> writeString(String data) async {
    await sendCommand(Uint8List.fromList(utf8.encode(data)));
  }

  @override
  Future<void> calibrate() async {
    if (_status != SensorStatus.reading) {
      debugPrint("⚠️ [SensorHubService] Cannot calibrate: Hub not reading.");
      return;
    }
    debugPrint("⚖️ [SensorHubService] Sending TARE command to scale hub...");
    await writeString(jsonEncode({'cmd': 'tare'}));
  }
}
