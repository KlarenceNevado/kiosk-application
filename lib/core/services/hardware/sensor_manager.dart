import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'sensor_service_interface.dart';
import 'mock_sensor_service.dart';
import 'drivers/serial_service.dart';
import 'drivers/sensor_hub_service.dart';
import 'sensor_data_models.dart';
import '../system/app_environment.dart';
import '../system/power_manager_service.dart';
import '../security/notification_service.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

class SensorManager {
  static final SensorManager _instance = SensorManager._internal();
  factory SensorManager() => _instance;
  SensorManager._internal() {
    _initSensors();
    _listenToPowerMode();
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
      debugPrint("🛠️ [SensorManager] Initializing REAL hardware with Dynamic Port Discovery.");
      _discoverAndAssignPorts();
    } else {
      debugPrint("🧪 [SensorManager] Initializing MOCK hardware for development.");
      for (var type in SensorType.values) {
        _sensors[type] = MockSensorService(type);
      }
    }

    // Listen to all registered sensors
    _setupSensorListeners();

    // Special Case: Pipe Hub secondary data (Temp and Battery)
    _setupHubSubscribers();
  }

  void _setupSensorListeners() {
    for (var type in _sensors.keys) {
      final service = _sensors[type]!;
      service.dataStream.listen((data) {
        _allDataController.add(SensorEvent(type: type, data: data, status: service.currentStatus));
      });
      service.statusStream.listen((status) {
        _allDataController.add(SensorEvent(type: type, status: status));
        if (status == SensorStatus.error || status == SensorStatus.disconnected) {
          NotificationService().showHardwareAlert(
            sensorName: type.toString().split('.').last.toUpperCase(),
            status: status.toString().split('.').last,
          );
        }
      });
    }
  }

  void _setupHubSubscribers() {
    if (_sensors[SensorType.weight] is SensorHubService) {
      final hub = _sensors[SensorType.weight] as SensorHubService;
      hub.secondaryDataStream.listen((tempData) {
        _allDataController.add(SensorEvent(type: SensorType.thermometer, data: tempData, status: hub.currentStatus));
      });
      hub.batteryStream.listen((voltage) {
        _allDataController.add(SensorEvent(type: SensorType.battery, data: voltage, status: hub.currentStatus));
        PowerManagerService().updateBatteryStatus(voltage);
      });
    }
  }

  Future<void> _discoverAndAssignPorts() async {
    final List<String> availablePorts = SerialPort.availablePorts;
    debugPrint("🔍 [SensorManager] Scanning ${availablePorts.length} ports for signatures...");

    String? foundHubPort;
    String? foundOxiPort;
    String? foundBpPort;

    for (var portName in availablePorts) {
      if (portName.contains("ttyAMA") || portName.contains("ttyS")) continue; // Skip internal Pi ports

      final port = SerialPort(portName);
      try {
        if (port.openReadWrite()) {
          port.config.baudRate = 9600;
          // In flutter_libserialport, setting the property on port.config is usually sufficient 
          // or assignment port.config = config is used. 

          // 1. Check for HUB (JSON signature)
          // We wait a short duration for a push-based JSON packet
          await Future.delayed(const Duration(milliseconds: 500));
          final reader = SerialPortReader(port);
          final Completer<String?> signatureCompleter = Completer();
          
          final subscription = reader.stream.listen((data) {
            final str = String.fromCharCodes(data);
            if (str.contains('"weight"') || str.contains('{')) {
              if (!signatureCompleter.isCompleted) signatureCompleter.complete("hub");
            } else if (data.isNotEmpty && data[0] == 0x81) {
              if (!signatureCompleter.isCompleted) signatureCompleter.complete("oximeter");
            }
          });

          // Also try active probe for BP
          final query = Uint8List.fromList([0x4D, 0x53, 0x54, 0x52]);
          port.write(query);

          final result = await signatureCompleter.future.timeout(
            const Duration(seconds: 1), 
            onTimeout: () => null
          );

          subscription.cancel();
          port.close();

          if (result == "hub") foundHubPort = portName;
          if (result == "oximeter") foundOxiPort = portName;
          // BP detection is tricky in a quick probe, we'll use exclusion if needed
        }
      } catch (e) {
        debugPrint("⚠️ [SensorManager] Error probing $portName: $e");
      }
    }

    // FALLBACKS & ASSIGNMENT
    final String finalHub = foundHubPort ?? (Platform.isWindows ? 'COM1' : '/dev/ttyUSB0');
    final String finalOxi = foundOxiPort ?? (Platform.isWindows ? 'COM2' : '/dev/ttyUSB1');
    final String finalBp = foundBpPort ?? (Platform.isWindows ? 'COM4' : '/dev/ttyUSB3');

    debugPrint("✅ [SensorManager] Hardware Mapping: Hub=$finalHub, Oxi=$finalOxi, BP=$finalBp");

    _sensors[SensorType.weight] = SensorHubService(type: SensorType.weight, portName: finalHub);
    _sensors[SensorType.thermometer] = SerialSensorService(type: SensorType.thermometer, portName: finalHub);
    _sensors[SensorType.oximeter] = SerialSensorService(type: SensorType.oximeter, portName: finalOxi, baudRate: 19200);
    _sensors[SensorType.bloodPressure] = SerialSensorService(type: SensorType.bloodPressure, portName: finalBp, baudRate: 9600);
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

  /// Sends the "MSTR" query command to the CONTEC08A Blood Pressure monitor
  /// to request stored measurement results.
  Future<void> queryBpResults() async {
    final bp = _sensors[SensorType.bloodPressure];
    if (bp != null) {
      debugPrint("📡 [SensorManager] Sending MSTR query to CONTEC BP monitor...");
      // 0x4D 0x53 0x54 0x52 is the common ASCII hex for "MSTR"
      final query = Uint8List.fromList([0x4D, 0x53, 0x54, 0x52]);
      await bp.sendCommand(query);
    }
  }

  void _listenToPowerMode() {
    PowerManagerService().modeStream.listen((mode) {
      if (mode == PowerMode.deepSleep) {
        debugPrint("🔋 [SensorManager] Deep Sleep: Stopping all sensor readings.");
        stopAll();
      }
    });
  }

  /// Manually updates the battery status (Used for Simulation and Testing).
  void updateBatteryVoltage(double voltage) {
    debugPrint("🔋 [SensorManager] Manual Battery Override: $voltage V");
    PowerManagerService().updateBatteryStatus(voltage);
  }

  void dispose() {
    stopAll();
    _allDataController.close();
  }
}
