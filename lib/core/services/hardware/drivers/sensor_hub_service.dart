import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../sensor_service_interface.dart';

/// specialized driver for the ESP32 Hub.
/// It reads JSON data and emits events for multiple sensor types.
class SensorHubService implements ISensorService {
  @override
  final SensorType type; // Principal type (e.g., weight) for ISensorService compatibility
  final String portName;
  final int baudRate;

  final _dataController = StreamController<dynamic>.broadcast();
  final _secondaryDataController = StreamController<dynamic>.broadcast();
  final _batteryDataController = StreamController<double>.broadcast();
  final _statusController = StreamController<SensorStatus>.broadcast();

  SensorStatus _status = SensorStatus.disconnected;
  SerialPort? _port;
  SerialPortReader? _reader;

  SensorHubService({
    required this.type,
    required this.portName,
    this.baudRate = 115200, // Higher baud for hub
  });

  @override
  Stream<dynamic> get dataStream => _dataController.stream;
  
  Stream<dynamic> get secondaryDataStream => _secondaryDataController.stream;

  Stream<double> get batteryStream => _batteryDataController.stream;

  @override
  Stream<SensorStatus> get statusStream => _statusController.stream;

  @override
  SensorStatus get currentStatus => _status;

  @override
  void startReading() async {
    if (_status == SensorStatus.reading || _status == SensorStatus.connecting) return;
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

      _reader = SerialPortReader(_port!);
      _reader!.stream.listen(_handleRawData);
    } catch (e) {
      _updateStatus(SensorStatus.error);
    }
  }

  @override
  void stopReading() {
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
    try {
      _stringBuffer += utf8.decode(bytes);
      _processStringBuffer();
    } catch (e) {
      // Ignore UTF-8 decode errors during mid-stream chunks
    }
  }

  void _processStringBuffer() {
    while (_stringBuffer.contains('{') && _stringBuffer.contains('}')) {
      final startIndex = _stringBuffer.indexOf('{');
      final endIndex = _stringBuffer.indexOf('}', startIndex);

      if (endIndex == -1) break; // Incomplete JSON

      final jsonString = _stringBuffer.substring(startIndex, endIndex + 1);
      
      try {
        final json = jsonDecode(jsonString);
        final String dataType = json['type'] ?? '';
        final value = json['value'];

        if (dataType == 'weight') {
          _dataController.add(value);
        } else if (dataType == 'temp') {
          _secondaryDataController.add(value);
        } else if (dataType == 'battery') {
          final double? batteryVal = double.tryParse(value.toString());
          if (batteryVal != null) {
            _batteryDataController.add(batteryVal);
          }
        }
      } catch (e) {
        debugPrint("⚠️ [SensorHubService] JSON Parse Error: $e");
      }

      // Remove processed part from buffer
      _stringBuffer = _stringBuffer.substring(endIndex + 1);
    }

    // Protection against runaway buffer
    if (_stringBuffer.length > 2048) {
      _stringBuffer = "";
    }
  }

  @override
  Future<void> sendCommand(Uint8List command) async {
    if (_port == null || _status != SensorStatus.reading) {
      debugPrint("⚠️ [SensorHubService] Cannot send command to Hub: Port not open.");
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
