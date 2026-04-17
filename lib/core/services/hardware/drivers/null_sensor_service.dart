import 'dart:async';
import 'dart:typed_data';
import '../sensor_service_interface.dart';

/// A safe "Null" implementation that ensures the app never crashes
/// when accessing a sensor that hasn't been discovered or initialized yet.
class NullSensorService implements ISensorService {
  @override
  final SensorType type;

  NullSensorService(this.type);

  @override
  Stream<dynamic> get dataStream => const Stream.empty();

  @override
  Stream<List<int>> get rawStream => const Stream.empty();

  @override
  Stream<SensorStatus> get statusStream => Stream.value(SensorStatus.disconnected);

  @override
  SensorStatus get currentStatus => SensorStatus.disconnected;

  @override
  void startReading() {
    // No-op
  }

  @override
  void stopReading() {
    // No-op
  }

  @override
  Future<void> sendCommand(Uint8List command) async {
    // No-op
  }

  @override
  Future<void> writeString(String data) async {
    // No-op
  }

  @override
  Future<void> calibrate() async {
    // No-op
  }
}
