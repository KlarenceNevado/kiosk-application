import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
      if (AppEnvironment().isKiosk && 
          !AppEnvironment().useSimulation && 
          (Platform.isWindows || Platform.isLinux)) {
        // Real Serial Ports for Desktop Kiosk
        // Use unique COM ports to avoid "Access is denied"
        final portMap = {
          SensorType.weight: Platform.isWindows ? 'COM1' : '/dev/ttyUSB0',
          SensorType.oximeter: Platform.isWindows ? 'COM2' : '/dev/ttyUSB1',
          SensorType.thermometer: Platform.isWindows ? 'COM3' : '/dev/ttyUSB2',
          SensorType.bloodPressure: Platform.isWindows ? 'COM4' : '/dev/ttyUSB3',
        };
        final portName = portMap[type] ?? (Platform.isWindows ? 'COM1' : '/dev/ttyUSB0');
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
      }, onError: (e) {
        debugPrint("❌ SensorManager [DataStream] Error for $type: $e");
        // Don't rethrow, just notify the unified stream
        _allDataController.add(SensorEvent(
          type: type,
          status: SensorStatus.error,
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
      }, onError: (e) {
        debugPrint("❌ SensorManager [StatusStream] Error for $type: $e");
      });
    }
  }

  ISensorService getSensor(SensorType type) => _sensors[type]!;

  /// Specialized accessors for convenience
  ISensorService get weightSensor => _sensors[SensorType.weight]!;
  ISensorService get oximeterSensor => _sensors[SensorType.oximeter]!;
  ISensorService get thermometerSensor => _sensors[SensorType.thermometer]!;
  ISensorService get bpSensor => _sensors[SensorType.bloodPressure]!;

  Future<void> startAll() async {
    for (var s in _sensors.values) {
      s.startReading();
      // STAGGERED START: Introduce a small delay between each sensor open
      // to spread out CPU/Bus load and avoid UI micro-stutters.
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }


  void stopAll() {
    for (var s in _sensors.values) {
      s.stopReading();
    }
  }

  void startSensor(SensorType type) {
    _sensors[type]?.startReading();
  }

  void stopSensor(SensorType type) {
    _sensors[type]?.stopReading();
  }

  void dispose() {
    stopAll();
    _allDataController.close();
  }
}

