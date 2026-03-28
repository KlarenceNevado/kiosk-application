import 'dart:async';
import 'dart:io';
import 'sensor_service_interface.dart';
import 'mock_sensor_service.dart';
import 'drivers/serial_service.dart';
import 'drivers/sensor_hub_service.dart';
import 'sensor_data_models.dart';
import '../system/system_log_service.dart';
import '../system/app_environment.dart';
import '../security/notification_service.dart';

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
    final bool isRealHardware = AppEnvironment().isKiosk && 
        !AppEnvironment().useSimulation && 
        (Platform.isWindows || Platform.isLinux);

    if (isRealHardware) {
      // PRODUCTION PORT MAPPING (From Integration Guide)
      final String hubPort = Platform.isWindows ? 'COM1' : '/dev/ttyUSB0';
      final String oximeterPort = Platform.isWindows ? 'COM2' : '/dev/ttyUSB1';
      final String bpPort = Platform.isWindows ? 'COM4' : '/dev/ttyUSB3';

      // 1. Initialize ESP32 HUB (Shared for Weight and Temp)
      final hub = SensorHubService(type: SensorType.weight, portName: hubPort);
      _sensors[SensorType.weight] = hub;
      
      // The thermometer uses the secondary stream from the hub
      // For now, we manually pipe it in the listener below, 
      // but we still need an entry in the map for status tracking.
      _sensors[SensorType.thermometer] = SerialSensorService(
        type: SensorType.thermometer, 
        portName: hubPort, 
      );

      // 2. Initialize Direct USB Sensors
      _sensors[SensorType.oximeter] = SerialSensorService(
        type: SensorType.oximeter, 
        portName: oximeterPort,
        baudRate: 19200, 
      );
      
      _sensors[SensorType.bloodPressure] = SerialSensorService(
        type: SensorType.bloodPressure, 
        portName: bpPort,
        baudRate: 9600, 
      );
    } else {
      // Mock sensors for development
      for (var type in SensorType.values) {
        _sensors[type] = MockSensorService(type);
      }
    }

    // Listen to all registered sensors
    for (var type in _sensors.keys) {
      final service = _sensors[type]!;
      
      service.dataStream.listen((data) {
        _allDataController.add(SensorEvent(
          type: type,
          data: data,
          status: service.currentStatus,
        ));
      });

      service.statusStream.listen((status) {
        _allDataController.add(SensorEvent(type: type, status: status));
        
        // Phase 2: Show OS-level notifications (Toasts) for failures
        if (status == SensorStatus.error || status == SensorStatus.disconnected) {
          NotificationService().showHardwareAlert(
            sensorName: type.toString().split('.').last.toUpperCase(),
            status: status.toString().split('.').last,
          );
          
          SystemLogService().logAction(
            action: 'SENSOR_STATUS_CHANGE',
            module: 'HARDWARE',
            severity: status == SensorStatus.error ? 'ERROR' : 'WARNING',
            sensorFailures: 'Sensor $type is now $status',
          );
        }
      });
    }

    // Special Case: Pipe Hub secondary data to Thermometer
    if (_sensors[SensorType.weight] is SensorHubService) {
      final hub = _sensors[SensorType.weight] as SensorHubService;
      hub.secondaryDataStream.listen((tempData) {
        _allDataController.add(SensorEvent(
          type: SensorType.thermometer,
          data: tempData,
          status: hub.currentStatus,
        ));
      });
    }
  }

  ISensorService getSensor(SensorType type) => _sensors[type]!;
  
  ISensorService get weightSensor => _sensors[SensorType.weight]!;
  ISensorService get oximeterSensor => _sensors[SensorType.oximeter]!;
  ISensorService get thermometerSensor => _sensors[SensorType.thermometer]!;
  ISensorService get bpSensor => _sensors[SensorType.bloodPressure]!;

  Future<void> startAll() async {
    for (var s in _sensors.values) {
      s.startReading();
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  void stopAll() {
    for (var s in _sensors.values) {
      s.stopReading();
    }
  }

  void startSensor(SensorType type) => _sensors[type]?.startReading();
  void stopSensor(SensorType type) => _sensors[type]?.stopReading();

  void dispose() {
    stopAll();
    _allDataController.close();
  }
}
