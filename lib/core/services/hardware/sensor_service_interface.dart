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
}
