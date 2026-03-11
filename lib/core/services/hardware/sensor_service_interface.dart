enum SensorStatus {
  disconnected,
  connecting,
  reading,
  error,
}

abstract class ISensorService {
  /// Stream of live heart rate numbers (0-200)
  Stream<int> get heartRateStream;

  /// Stream of the connection status (Connecting, Error, etc.)
  Stream<SensorStatus> get statusStream;

  /// Current status value
  SensorStatus get currentStatus;

  void startReading();
  void stopReading();
}
