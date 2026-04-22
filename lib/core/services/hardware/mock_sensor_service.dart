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
    await Future.delayed(const Duration(milliseconds: 800));

    _updateStatus(SensorStatus.reading);

    // Initial base values for this "session"
    double targetWeight = 62.0 + _random.nextDouble() * 15.0; // 62-77 kg
    double targetTemp = 36.4 + _random.nextDouble() * 0.4;    // 36.4-36.8 C
    int targetSpo2 = 96 + _random.nextInt(4);               // 96-99%
    int targetBpm = 68 + _random.nextInt(12);               // 68-80 bpm
    int targetSys = 110 + _random.nextInt(15);              // 110-125
    int targetDia = 70 + _random.nextInt(10);               // 70-80

    int ticks = 0;
    const int maxTicks = 20; // ~5 seconds at 250ms

    _timer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      ticks++;
      dynamic value;

      // Realistic fluctuation logic
      double progress = ticks / maxTicks;
      if (progress > 1.0) progress = 1.0;

      switch (type) {
        case SensorType.weight:
          // Start at 0, climb to weight, then fluctuate slightly
          double current = (ticks < 5) ? (targetWeight * (ticks / 5.0)) : targetWeight;
          value = current + (_random.nextDouble() * 0.2 - 0.1);
          break;
        case SensorType.oximeter:
          value = {
            'spo2': targetSpo2 + (ticks % 2 == 0 ? 0 : (_random.nextInt(2) - 1)),
            'bpm': targetBpm + (_random.nextInt(3) - 1)
          };
          break;
        case SensorType.thermometer:
          // Warm up simulation
          double current = 32.0 + (targetTemp - 32.0) * progress;
          value = current + (_random.nextDouble() * 0.1 - 0.05);
          break;
        case SensorType.bloodPressure:
          if (ticks < 12) {
            // Pumping phase
            value = {'type': 'realtime', 'pressure': ticks * 15};
          } else {
            // Result phase
            value = {
              'type': 'result',
              'sys': targetSys,
              'dia': targetDia,
              'hr': targetBpm
            };
          }
          break;
        case SensorType.battery:
          value = 12.4 + (_random.nextDouble() * 0.2);
          break;
        case SensorType.height:
          value = 165.0 + _random.nextInt(10);
          break;
        case SensorType.fingerprint:
          // Simulate a match after 2 seconds
          if (ticks == 8) {
            value = {'type': 'fingerprint_match', 'id': 1};
          }
          break;
      }

      _dataController.add(value);

      // Auto-lock after enough ticks to simulate "Proper Calibration"
      if (ticks >= maxTicks) {
        _updateStatus(SensorStatus.stable);
        // Explicitly send one final stable data packet
        _dataController.add(value);
        _timer?.cancel();
      }
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
