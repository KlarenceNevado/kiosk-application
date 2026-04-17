import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'sensor_service_interface.dart';

class MockSensorService implements ISensorService {
  @override
  final SensorType type;

  final _dataController = StreamController<dynamic>.broadcast();
  final _statusController = StreamController<SensorStatus>.broadcast();

  Timer? _timer;
  final Random _random = Random();
  SensorStatus _status = SensorStatus.disconnected;

  MockSensorService(this.type);

  @override
  Stream<dynamic> get dataStream => _dataController.stream;

  @override
  Stream<List<int>> get rawStream => const Stream.empty();

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
    await Future.delayed(const Duration(seconds: 1)); // Faster for testing

    _updateStatus(SensorStatus.reading);

    _timer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      dynamic value;
      switch (type) {
        case SensorType.weight:
          // Smooth increment until ~70kg
          double baseWeight = 70.0;
          value = baseWeight + (_random.nextDouble() * 0.5);
          break;
        case SensorType.oximeter:
          value = {
            'spo2': 97 + _random.nextInt(3),
            'bpm': 72 + _random.nextInt(10)
          };
          break;
        case SensorType.thermometer:
          value = 36.6 + (_random.nextDouble() * 0.4);
          break;
        case SensorType.bloodPressure:
          // Simulate the "pumping" feel or just fluctuating final values
          value = {
            'sys': 115 + _random.nextInt(10),
            'dia': 75 + _random.nextInt(10)
          };
          break;
        case SensorType.battery:
          value = 12.0 + (_random.nextDouble() * 2.0);
          break;
        case SensorType.height:
          // Simulate height around 160-170cm
          value = 160.0 + _random.nextInt(15);
          break;
      }

      _dataController.add(value);
    });
  }

  @override
  void stopReading() {
    _timer?.cancel();
    _updateStatus(SensorStatus.disconnected);
  }

  void _updateStatus(SensorStatus status) {
    _status = status;
    _statusController.add(status);
  }

  @override
  Future<void> sendCommand(Uint8List command) async {
    // Mimic the Uint8List or dynamic command
    // In mock, we just log it.
    debugPrint("🧪 [MockSensorService] $type received command: $command");
  }

  @override
  Future<void> writeString(String data) async {
    debugPrint("🧪 [MockSensorService] $type received string: $data");
  }

  @override
  Future<void> calibrate() async {
    debugPrint("🧪 [MockSensorService] Calibrating $type...");
    await Future.delayed(const Duration(seconds: 2));
    debugPrint("🧪 [MockSensorService] Calibration complete for $type.");
  }

  void dispose() {
    _dataController.close();
    _statusController.close();
  }
}
