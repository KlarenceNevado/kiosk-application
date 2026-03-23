import 'dart:async';
import 'dart:io';
import 'sensor_service_interface.dart';
import 'mock_sensor_service.dart';
import 'drivers/serial_service.dart';
import 'sensor_data_models.dart';
import '../system/system_log_service.dart';
import '../system/app_environment.dart';

class SensorManager {
  static final SensorManager _instance = SensorManager._internal();
  factory SensorManager() => _instance;
  SensorManager._internal() {
    _initSensors();
  }

  final Map<SensorType, ISensorService> _sensors = {};
  
  // Unified stream for all sensor events
  final _allDataController = StreamController<SensorEvent>.broadcast();
  Stream<SensorEvent> get allDataStream => _allDataController.stream;

  void _initSensors() {
    // For now, we initialize all as Mock services in "standby" mode
    // These can be replaced with SerialSensorService when real hardware is defined
    for (var type in SensorType.values) {
      if (AppEnvironment().isKiosk && (Platform.isWindows || Platform.isLinux)) {
        // Real Serial Ports for Desktop Kiosk
        final portName = Platform.isWindows ? 'COM3' : '/dev/ttyUSB0';
        _sensors[type] = SerialSensorService(type: type, portName: portName);
      } else {
        _sensors[type] = MockSensorService(type);
      }
      
      // Listen to each sensor and pipe to the unified controller
      _sensors[type]!.dataStream.listen((data) {
        _allDataController.add(SensorEvent(
          type: type,
          data: data,
          status: _sensors[type]!.currentStatus,
        ));
      });

      _sensors[type]!.statusStream.listen((status) {
        _allDataController.add(SensorEvent(
          type: type,
          status: status,
        ));

        // Log sensor failures or warnings
        if (status == SensorStatus.error || status == SensorStatus.disconnected) {
          SystemLogService().logAction(
            action: 'SENSOR_STATUS_CHANGE',
            module: 'HARDWARE',
            severity: status == SensorStatus.error ? 'ERROR' : 'WARNING',
            sensorFailures: 'Sensor $type is now $status',
          );
        }
      });
    }
  }

  ISensorService getSensor(SensorType type) => _sensors[type]!;

  /// Specialized accessors for convenience
  ISensorService get weightSensor => _sensors[SensorType.weight]!;
  ISensorService get oximeterSensor => _sensors[SensorType.oximeter]!;
  ISensorService get thermometerSensor => _sensors[SensorType.thermometer]!;
  ISensorService get bpSensor => _sensors[SensorType.bloodPressure]!;

  void startAll() {
    for (var s in _sensors.values) {
      s.startReading();
    }
  }

  void stopAll() {
    for (var s in _sensors.values) {
      s.stopReading();
    }
  }

  void dispose() {
    stopAll();
    _allDataController.close();
  }
}
