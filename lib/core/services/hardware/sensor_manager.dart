import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'sensor_service_interface.dart';
import 'mock_sensor_service.dart';
import 'drivers/serial_service.dart';
import 'drivers/sensor_hub_service.dart';
import 'sensor_data_models.dart';
import 'models/hardware_config.dart';
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

    _setupSensorListeners();
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
    final config = HardwareConfig.instance;
    final List<String> availablePorts = SerialPort.availablePorts;
    debugPrint("🔍 [SensorManager] Scanning ${availablePorts.length} ports using dynamic config...");

    String? foundHubPort = config.hub.portOverride;
    String? foundOxiPort = config.oximeter.portOverride;
    String? foundBpPort = config.bloodPressure.portOverride;

    List<String> portsToScan = availablePorts.where((p) => 
      p != foundHubPort && p != foundOxiPort && p != foundBpPort
    ).toList();

    for (var portName in portsToScan) {
      final port = SerialPort(portName);
      try {
        if (port.openReadWrite()) {
          port.config.baudRate = 9600;

          final reader = SerialPortReader(port);
          final Completer<String?> signatureCompleter = Completer();
          
          final subscription = reader.stream.listen((data) {
            final str = String.fromCharCodes(data);
            
            if (config.hub.handshakeSignature != null && str.contains(config.hub.handshakeSignature!)) {
              if (!signatureCompleter.isCompleted) signatureCompleter.complete("hub");
            } 
            else if (config.oximeter.handshakeSignatureHex != null) {
              final sig = int.tryParse(config.oximeter.handshakeSignatureHex!, radix: 16);
              if (data.isNotEmpty && sig != null && data[0] == sig) {
                if (!signatureCompleter.isCompleted) signatureCompleter.complete("oximeter");
              }
            }
          });

          if (config.bloodPressure.handshakeSignature != null) {
            final query = Uint8List.fromList(config.bloodPressure.handshakeSignature!.codeUnits);
            port.write(query);
          }

          final result = await signatureCompleter.future.timeout(
            Duration(milliseconds: config.system.discoveryTimeoutMs), 
            onTimeout: () => null
          );

          subscription.cancel();
          port.close();

          if (result == "hub") foundHubPort = portName;
          if (result == "oximeter") foundOxiPort = portName;
        }
      } catch (e) {
        debugPrint("⚠️ [SensorManager] Error probing $portName: $e");
      }
    }

    final String finalHub = foundHubPort ?? (Platform.isWindows ? 'COM1' : '/dev/ttyAMA0');
    final String finalOxi = foundOxiPort ?? (Platform.isWindows ? 'COM2' : '/dev/ttyUSB0');
    final String finalBp = foundBpPort ?? (Platform.isWindows ? 'COM4' : '/dev/ttyUSB1');

    debugPrint("✅ [SensorManager] Mapping: Hub=$finalHub, Oxi=$finalOxi, BP=$finalBp");

    _sensors[SensorType.weight] = SensorHubService(
      type: SensorType.weight, 
      portName: finalHub,
      baudRate: config.hub.baudRate
    );
    _sensors[SensorType.thermometer] = SerialSensorService(
      type: SensorType.thermometer, 
      portName: finalHub,
      baudRate: config.hub.baudRate
    );
    _sensors[SensorType.oximeter] = SerialSensorService(
      type: SensorType.oximeter, 
      portName: finalOxi, 
      baudRate: config.oximeter.baudRate
    );
    _sensors[SensorType.bloodPressure] = SerialSensorService(
      type: SensorType.bloodPressure, 
      portName: finalBp, 
      baudRate: config.bloodPressure.baudRate
    );
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

  Future<void> queryBpResults() async {
    final bp = _sensors[SensorType.bloodPressure];
    if (bp != null) {
      debugPrint("📡 [SensorManager] Sending MSTR query to CONTEC BP monitor...");
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

  void updateBatteryVoltage(double voltage) {
    debugPrint("🔋 [SensorManager] Manual Battery Override: $voltage V");
    PowerManagerService().updateBatteryStatus(voltage);
  }

  void dispose() {
    stopAll();
    _allDataController.close();
  }
}
