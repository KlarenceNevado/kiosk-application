import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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
  final _statusController = StreamController<SensorStatus>.broadcast();
  
  // Secondary stream for the other sensor type on the same hub
  final _secondaryDataController = StreamController<dynamic>.broadcast();

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

  void _handleRawData(Uint8List bytes) {
    try {
      final text = utf8.decode(bytes).trim();
      if (!text.startsWith('{')) return;

      final json = jsonDecode(text);
      final String dataType = json['type'] ?? '';
      final value = json['value'];

      if (dataType == 'weight') {
        _dataController.add(value);
      } else if (dataType == 'temp') {
        _secondaryDataController.add(value);
      }
    } catch (e) {
      // Ignore malformed JSON fragments
    }
  }
}
