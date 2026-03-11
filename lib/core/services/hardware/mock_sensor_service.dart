import 'dart:async';
import 'dart:math';
import 'sensor_service_interface.dart';

class MockSensorService implements ISensorService {
  final _heartRateController = StreamController<int>.broadcast();
  final _statusController = StreamController<SensorStatus>.broadcast();

  Timer? _timer;
  final Random _random = Random();
  SensorStatus _status = SensorStatus.disconnected;

  @override
  Stream<int> get heartRateStream => _heartRateController.stream;

  @override
  Stream<SensorStatus> get statusStream => _statusController.stream;

  @override
  SensorStatus get currentStatus => _status;

  @override
  void startReading() async {
    if (_status == SensorStatus.reading || _status == SensorStatus.connecting) {
      return;
    }

    // 1. Simulate Connection Delay
    _updateStatus(SensorStatus.connecting);
    await Future.delayed(const Duration(seconds: 2)); // Fake hardware handshake

    // 2. Start Data Stream
    _updateStatus(SensorStatus.reading);

    // 3. Generate Realistic Heartbeat (Sine wave + noise)
    int tick = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      tick++;
      // Sine wave base (60-100) + Random noise
      double base = 80 + (10 * sin(tick * 0.5));
      int noise = _random.nextInt(5) - 2;
      int value = (base + noise).round();

      _heartRateController.add(value);
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

  void dispose() {
    _heartRateController.close();
    _statusController.close();
  }
}
