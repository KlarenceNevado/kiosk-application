import 'dart:async';
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

    _timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      dynamic value;
      switch (type) {
        case SensorType.weight:
          value = 70.0 + _random.nextDouble() * 2;
          break;
        case SensorType.oximeter:
          value = { 'spo2': 95 + _random.nextInt(5), 'bpm': 70 + _random.nextInt(20) };
          break;
        case SensorType.thermometer:
          value = 36.5 + _random.nextDouble();
          break;
        case SensorType.bloodPressure:
          value = { 'sys': 110 + _random.nextInt(20), 'dia': 70 + _random.nextInt(15) };
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

  void dispose() {
    _dataController.close();
    _statusController.close();
  }
}
