import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../sensor_service_interface.dart';

/// Driver for R307 Fingerprint Sensor via Serial
class FingerprintService implements ISensorService {
  @override
  final SensorType type = SensorType.fingerprint; 

  final String portName;
  final int baudRate;

  final _dataController = StreamController<dynamic>.broadcast();
  final _statusController = StreamController<SensorStatus>.broadcast();
  final _rawController = StreamController<List<int>>.broadcast();

  SensorStatus _status = SensorStatus.disconnected;
  SerialPort? _port;
  SerialPortReader? _reader;
  Timer? _pollingTimer;

  FingerprintService({
    required this.portName,
    this.baudRate = 57600,
  });

  @override
  Stream<dynamic> get dataStream => _dataController.stream;
  @override
  Stream<List<int>> get rawStream => _rawController.stream;
  @override
  Stream<SensorStatus> get statusStream => _statusController.stream;
  @override
  SensorStatus get currentStatus => _status;

  @override
  void startReading() async {
    if (_status == SensorStatus.reading || _status == SensorStatus.connecting) return;
    _updateStatus(SensorStatus.connecting);

    try {
      _port = SerialPort(portName);
      if (!_port!.openReadWrite()) {
        throw Exception("Could not open fingerprint port $portName");
      }

      _port!.config = SerialPortConfig()
        ..baudRate = baudRate
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none;

      _updateStatus(SensorStatus.reading);
      
      _reader = SerialPortReader(_port!);
      _reader!.stream.listen(_handleRawData);

      // Perform Handshake
      await _sendHandshake();
      
      // Start polling for finger
      _startPolling();
    } catch (e) {
      debugPrint("❌ [FingerprintService] Init Error: $e");
      _updateStatus(SensorStatus.error);
    }
  }

  @override
  void stopReading() {
    _pollingTimer?.cancel();
    _reader?.close();
    _port?.close();
    _port = null;
    _updateStatus(SensorStatus.disconnected);
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (_status != SensorStatus.reading) return;
      await _searchFingerprint();
    });
  }

  // --- R307 Protocol Logic ---

  Future<void> _sendHandshake() async {
    // EF 01 | FF FF FF FF | 01 | 00 03 | 01 | 00 05
    final cmd = Uint8List.fromList([0xEF, 0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0x01, 0x00, 0x03, 0x01, 0x00, 0x05]);
    await sendCommand(cmd);
  }

  Future<void> _searchFingerprint() async {
    // 1. Get Image: EF 01 | FF FF FF FF | 01 | 00 03 | 01 | 00 05
    final getImage = Uint8List.fromList([0xEF, 0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0x01, 0x00, 0x03, 0x01, 0x00, 0x05]);
    await sendCommand(getImage);
    
    // In a real implementation, we wait for 'Image Taken' then call 'Generate Feature' then 'Search'.
    // For this kiosk implementation, we'll implement a 'Auto-Search' cycle.
  }

  @override
  Future<void> sendCommand(Uint8List command) async {
    if (_port == null || !_port!.isOpen) return;
    try {
      _port!.write(command);
    } catch (e) {
      debugPrint("❌ [FingerprintService] Write Error: $e");
    }
  }

  @override
  Future<void> writeString(String data) async => sendCommand(Uint8List.fromList(data.codeUnits));

  @override
  Future<void> calibrate() async {}

  void _updateStatus(SensorStatus status) {
    _status = status;
    _statusController.add(status);
  }

  final List<int> _buffer = [];

  void _handleRawData(Uint8List data) {
    _rawController.add(data);
    _buffer.addAll(data);
    _processBuffer();
  }

  void _processBuffer() {
    // Implementation of R307 response parsing
    // Header: EF 01 ...
    while (_buffer.length >= 9) {
      if (_buffer[0] == 0xEF && _buffer[1] == 0x01) {
        final length = (_buffer[7] << 8) | _buffer[8];
        if (_buffer.length >= 9 + length) {
          final packet = _buffer.sublist(0, 9 + length);
          _handlePacket(packet);
          _buffer.removeRange(0, 9 + length);
          continue;
        }
      } else {
        _buffer.removeAt(0);
      }
      break;
    }
  }

  void _handlePacket(List<int> packet) {
    // Packet[9] is the confirmation code. 00 = Success.
    if (packet.length > 9 && packet[9] == 0x00) {
      // If it's a Search result, packet[10-11] is the PageID (Fingerprint ID)
      if (packet.length >= 14 && packet[6] == 0x07) { // 07 is Ack for Search
        final fingerId = (packet[10] << 8) | packet[11];
        final confidence = (packet[12] << 8) | packet[13];
        
        if (confidence > 50) {
          _dataController.add({
            'type': 'fingerprint_match',
            'id': fingerId,
            'confidence': confidence,
          });
        }
      }
    }
  }

  void dispose() {
    stopReading();
    _dataController.close();
    _statusController.close();
    _rawController.close();
  }
}
