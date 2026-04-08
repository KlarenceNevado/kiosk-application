import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../sensor_service_interface.dart';
import '../parsers/weight_parser.dart';
import '../parsers/spo2_parser.dart';
import '../parsers/temp_parser.dart';
import '../parsers/contec_bp_parser.dart';

/// Generic driver for Serial (USB) sensors.
class SerialSensorService implements ISensorService {
  @override
  final SensorType type;
  final String portName;
  final int baudRate;

  final _dataController = StreamController<dynamic>.broadcast();
  final _statusController = StreamController<SensorStatus>.broadcast();

  SensorStatus _status = SensorStatus.disconnected;
  SerialPort? _port;
  SerialPortReader? _reader;
  Timer? _watchdogTimer;
  DateTime? _lastDataReceived;

  SerialSensorService({
    required this.type,
    required this.portName,
    this.baudRate = 9600,
  });

  @override
  Stream<dynamic> get dataStream => _dataController.stream;

  @override
  Stream<SensorStatus> get statusStream => _statusController.stream;

  @override
  SensorStatus get currentStatus => _status;

  static List<String>? _availablePortsCache;
  static DateTime? _lastCacheUpdate;

  @override
  void startReading() async {
    // YIELD IMMEDIATELY: Ensure the UI/event loop can respond to the tap action
    // before the potentially heavy serial port operations begin.
    await Future.delayed(Duration.zero);

    if (_status == SensorStatus.reading || _status == SensorStatus.connecting) {
      return;
    }

    _updateStatus(SensorStatus.connecting);

    try {
      // SMART CACHE: Check if port exists before attempting to open
      // Use a 5-second cache to avoid redundant bus scans across multiple sensors.
      if (_availablePortsCache == null ||
          _lastCacheUpdate == null ||
          DateTime.now().difference(_lastCacheUpdate!).inSeconds > 5) {
        _availablePortsCache = SerialPort.availablePorts;
        _lastCacheUpdate = DateTime.now();
      }

      if (!_availablePortsCache!.contains(portName)) {
        _updateStatus(SensorStatus.disconnected);
        debugPrint(
            "ℹ️ [SerialSensorService] Port $portName not found. Hardware is likely disconnected.");
        return;
      }

      _port = SerialPort(portName);

      if (!_port!.openReadWrite()) {
        throw Exception(
            "Could not open port $portName. Error: ${SerialPort.lastError}");
      }

      // Configure port
      _port!.config = SerialPortConfig()
        ..baudRate = baudRate
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none;

      _updateStatus(SensorStatus.reading);
      _startWatchdog();

      // Start reading stream
      _reader = SerialPortReader(_port!);
      _reader!.stream.listen(_handleRawData, onError: (e) {
        _updateStatus(SensorStatus.error);
        _dataController.addError("Serial stream error: $e");
      });
    } catch (e) {
      _updateStatus(SensorStatus.error);
      _dataController.addError("Serial Connection Failed: $e");
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

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _lastDataReceived = DateTime.now();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_status != SensorStatus.reading) {
        timer.cancel();
        return;
      }

      final idleTime = DateTime.now().difference(_lastDataReceived!).inSeconds;
      if (idleTime > 8) {
        // 8 second silence = Hang
        debugPrint(
            "⚠️ [SerialWatchdog] No data from $type for 8s. Auto-reconnecting...");
        _reconnect();
      }
    });
  }

  void _reconnect() async {
    _reader?.close();
    _port?.close();
    await Future.delayed(const Duration(seconds: 1));
    startReading();
  }

  @override
  Future<void> calibrate() async {
    // Standard serial sensors usually don't support remote calibration
    // unless they have a specific command protocol. Handled by Hub.
    debugPrint(
        "ℹ️ [SerialSensorService] $type does not support software calibration.");
  }

  void _updateStatus(SensorStatus status) {
    _status = status;
    _statusController.add(status);
  }

  @override
  Future<void> sendCommand(Uint8List command) async {
    if (_port == null || _status != SensorStatus.reading) {
      debugPrint(
          "⚠️ [SerialSensorService] Cannot send command to $type: Port not open.");
      return;
    }
    try {
      final bytesWritten = _port!.write(command);
      if (bytesWritten != command.length) {
        debugPrint(
            "⚠️ [SerialSensorService] Partial write for $type. Sent $bytesWritten/${command.length}");
      }
    } catch (e) {
      debugPrint("❌ [SerialSensorService] Error sending command to $type: $e");
    }
  }

  @override
  Future<void> writeString(String data) async {
    await sendCommand(Uint8List.fromList(data.codeUnits));
  }

  void dispose() {
    stopReading();
    _dataController.close();
    _statusController.close();
  }

  final List<int> _buffer = [];

  void _handleRawData(Uint8List bytes) {
    _lastDataReceived = DateTime.now();
    _buffer.addAll(bytes);
    _processBuffer();
  }

  void _processBuffer() {
    bool foundPacket = true;

    while (foundPacket && _buffer.isNotEmpty) {
      foundPacket = false;
      final currentBuffer = Uint8List.fromList(_buffer);

      switch (type) {
        case SensorType.weight:
          // ASCII Weight typically ends with \n or \r
          final newlineIndex = _buffer.indexOf(10); // \n
          if (newlineIndex != -1) {
            final packet =
                Uint8List.fromList(_buffer.sublist(0, newlineIndex + 1));
            final weight = WeightParser.parse(packet);
            if (weight != null) _dataController.add(weight);
            _buffer.removeRange(0, newlineIndex + 1);
            foundPacket = true;
          }
          break;

        case SensorType.oximeter:
          final result = SpO2Parser.parse(currentBuffer);
          if (result != null) {
            _dataController.add(result.data);
            _buffer.removeRange(0, result.bytesConsumed);
            foundPacket = true;
          }
          break;

        case SensorType.bloodPressure:
          final result = ContecBpParser.parse(currentBuffer);
          if (result != null) {
            _dataController.add(result.data);
            _buffer.removeRange(0, result.bytesConsumed);
            foundPacket = true;
          }
          break;

        case SensorType.thermometer:
          // Assuming standalone thermometer also uses ASCII/Newline
          final newlineIndex = _buffer.indexOf(10);
          if (newlineIndex != -1) {
            final packet =
                Uint8List.fromList(_buffer.sublist(0, newlineIndex + 1));
            final temp = TempParser.parse(packet);
            if (temp != null) _dataController.add(temp);
            _buffer.removeRange(0, newlineIndex + 1);
            foundPacket = true;
          }
          break;
        case SensorType.battery:
          // Battery data is typically handled by the Hub JSON, but added for exhaustiveness
          break;
      }

      // Safeguard: If buffer is getting too large without finding a packet,
      // clear old data to prevent memory issues.
      if (_buffer.length > 1024) {
        debugPrint(
            "⚠️ [SerialSensorService] Buffer overflow for $type. Clearing...");
        _buffer.clear();
        break;
      }
    }
  }
}
