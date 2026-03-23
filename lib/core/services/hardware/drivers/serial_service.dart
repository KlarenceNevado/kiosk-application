import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../sensor_service_interface.dart';
import '../parsers/weight_parser.dart';
import '../parsers/spo2_parser.dart';
import '../parsers/temp_parser.dart';

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

  @override
  void startReading() async {
    if (_status == SensorStatus.reading || _status == SensorStatus.connecting) {
      return;
    }

    _updateStatus(SensorStatus.connecting);
    
    try {
      _port = SerialPort(portName);
      
      if (!_port!.openReadWrite()) {
        throw Exception("Could not open port $portName. Error: ${SerialPort.lastError}");
      }
      
      // Configure port
      _port!.config = SerialPortConfig()
        ..baudRate = baudRate
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none;

      _updateStatus(SensorStatus.reading);
      
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
    _reader?.close();
    _port?.close();
    _port = null;
    _updateStatus(SensorStatus.disconnected);
  }

  void _updateStatus(SensorStatus status) {
    _status = status;
    _statusController.add(status);
  }

  void dispose() {
    stopReading();
    _dataController.close();
    _statusController.close();
  }

  void _handleRawData(Uint8List bytes) {
    dynamic parsedData;
    
    switch (type) {
      case SensorType.weight:
        parsedData = WeightParser.parse(bytes);
        break;
      case SensorType.oximeter:
        parsedData = SpO2Parser.parse(bytes);
        break;
      case SensorType.thermometer:
        parsedData = TempParser.parse(bytes);
        break;
      case SensorType.bloodPressure:
        // BP usually has its own complex binary protocol (e.g. OMRON)
        parsedData = bytes; 
        break;
    }

    if (parsedData != null) {
      _dataController.add(parsedData);
    }
  }
}
