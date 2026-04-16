import 'dart:typed_data';

enum SensorStatus {
  disconnected,
  connecting,
  reading,
  error,
}

enum SensorType {
  weight,
  oximeter,
  thermometer,
  bloodPressure,
  battery,
  height,
}

abstract class ISensorService {
  SensorType get type;

  /// Stream of connection status
  Stream<SensorStatus> get statusStream;

  /// Current status value
  SensorStatus get currentStatus;

  /// Stream of raw OR parsed data
  Stream<dynamic> get dataStream;

  void startReading();
  void stopReading();

  /// Sends raw hexadecimal commands to the sensor
  Future<void> sendCommand(Uint8List command);

  /// Sends ASCII strings (mostly for Hub or AT commands)
  Future<void> writeString(String data);

  /// Triggers a hardware calibration (e.g., Tare for Scale, Zero for Temp)
  Future<void> calibrate();
}
