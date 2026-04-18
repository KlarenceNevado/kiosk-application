import 'dart:async';
import 'dart:io';
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
  final _rawController = StreamController<List<int>>.broadcast();

  SensorStatus _status = SensorStatus.disconnected;
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription? _hidStreamSub;
  RandomAccessFile? _hidFile;
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
  Stream<List<int>> get rawStream => _rawController.stream;

  @override
  Stream<SensorStatus> get statusStream => _statusController.stream;

  @override
  SensorStatus get currentStatus => _status;

  static List<String>? _availablePortsCache;
  static DateTime? _lastCacheUpdate;

  @override
  void startReading() async {
    await Future.delayed(Duration.zero);

    if (_status == SensorStatus.reading || _status == SensorStatus.connecting) {
      return;
    }

    _updateStatus(SensorStatus.connecting);

    try {
      if (portName.startsWith('/dev/hidraw')) {
        final file = File(portName);
        if (!file.existsSync()) {
          _updateStatus(SensorStatus.disconnected);
          debugPrint("ℹ️ [SerialSensorService] HID port $portName not found.");
          return;
        }

        _updateStatus(SensorStatus.reading);
        _startWatchdog();

        final openFile = await file.open(mode: FileMode.append);
        _hidFile = openFile;

        _hidStreamSub = file.openRead().listen(_handleRawData, onError: (e) {
          _updateStatus(SensorStatus.error);
          _dataController.addError("HID stream error: $e");
        });
        return;
      }

      if (_availablePortsCache == null ||
          _lastCacheUpdate == null ||
          DateTime.now().difference(_lastCacheUpdate!).inSeconds > 5) {
        _availablePortsCache = SerialPort.availablePorts;
        _lastCacheUpdate = DateTime.now();
      }

      if (!_availablePortsCache!.contains(portName)) {
        _updateStatus(SensorStatus.disconnected);
        debugPrint("ℹ️ [SerialSensorService] Port $portName not found.");
        return;
      }

      _port = SerialPort(portName);

      if (!_port!.openReadWrite()) {
        throw Exception("Could not open port $portName.");
      }

      _port!.config = SerialPortConfig()
        ..baudRate = baudRate
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none
        ..setFlowControl(SerialPortFlowControl.none);

      _port!.flush(); // Clear extender noise 
      
      _updateStatus(SensorStatus.reading);
      _startWatchdog();

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
    _hidStreamSub?.cancel();
    _hidFile?.closeSync();
    _hidFile = null;
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
        debugPrint("⚠️ [SerialWatchdog] No data from $type for 8s.");
        _reconnect();
      }
    });
  }

  void _reconnect() async {
    _hidStreamSub?.cancel();
    _reader?.close();
    _port?.close();
    await Future.delayed(const Duration(seconds: 1));
    startReading();
  }

  @override
  Future<void> calibrate() async {
    debugPrint("ℹ️ [SerialSensorService] $type does not support software calibration.");
  }

  void _updateStatus(SensorStatus status) {
    _status = status;
    _statusController.add(status);
  }

  @override
  Future<void> sendCommand(Uint8List command) async {
    if (_status != SensorStatus.reading) return;
    try {
      if (portName.startsWith('/dev/hidraw') && _hidFile != null) {
        final hidPacket = Uint8List(command.length + 1);
        hidPacket[0] = 0x00; 
        hidPacket.setRange(1, hidPacket.length, command);
        await _hidFile!.writeFrom(hidPacket);
        return;
      }
      if (_port == null) return;
      _port!.write(command);
    } catch (e) {
      debugPrint("❌ [SerialSensorService] Command error: $e");
    }
  }

  @override
  Future<void> writeString(String data) async {
    await sendCommand(Uint8List.fromList(data.codeUnits));
  }

  void dispose() {
    stopReading();
    _dataController.close();
    _rawController.close();
    _statusController.close();
  }

  final List<int> _buffer = [];

  void _handleRawData(List<int> bytes) {
    _lastDataReceived = DateTime.now();
    _rawController.add(bytes);
    _buffer.addAll(bytes);
    _processBuffer();
  }

  void _processBuffer() {
    bool foundPacket = true;

    while (foundPacket && _buffer.isNotEmpty) {
      foundPacket = false;
      final currentBuffer = Uint8List.fromList(_buffer);

      // MULTIPLEXED PARSING: Try Oximeter then BP
      if (type == SensorType.oximeter || type == SensorType.bloodPressure) {
        final spo2Res = SpO2Parser.parse(currentBuffer);
        if (spo2Res != null) {
          _dataController.add(spo2Res.data);
          _buffer.removeRange(0, spo2Res.bytesConsumed);
          foundPacket = true;
          continue;
        }
        final bpRes = ContecBpParser.parse(currentBuffer);
        if (bpRes != null) {
          _dataController.add(bpRes.data);
          _buffer.removeRange(0, bpRes.bytesConsumed);
          foundPacket = true;
          continue;
        }
      }

      switch (type) {
        case SensorType.weight:
          final newlineIndex = _buffer.indexOf(10);
          if (newlineIndex != -1) {
            final packet = Uint8List.fromList(_buffer.sublist(0, newlineIndex + 1));
            final weight = WeightParser.parse(packet);
            if (weight != null) _dataController.add(weight);
            _buffer.removeRange(0, newlineIndex + 1);
            foundPacket = true;
          }
          break;

        case SensorType.thermometer:
          final newlineIndex = _buffer.indexOf(10);
          if (newlineIndex != -1) {
            final packet = Uint8List.fromList(_buffer.sublist(0, newlineIndex + 1));
            final temp = TempParser.parse(packet);
            if (temp != null) _dataController.add(temp);
            _buffer.removeRange(0, newlineIndex + 1);
            foundPacket = true;
          }
          break;
        case SensorType.battery:
          _buffer.clear(); // Handled by Hub
          break;
        case SensorType.height:
          _buffer.clear();
          break;
        default:
          _buffer.clear();
          break;
      }

      if (_buffer.length > 2048) {
        _buffer.clear();
        break;
      }
    }
  }
}
