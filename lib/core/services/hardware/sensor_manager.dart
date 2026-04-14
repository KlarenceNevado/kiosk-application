import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'sensor_service_interface.dart';
import 'mock_sensor_service.dart';
import 'drivers/serial_service.dart';
import 'drivers/sensor_hub_service.dart';
import 'sensor_data_models.dart';
import 'drivers/null_sensor_service.dart';
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
      debugPrint(
          "🛠️ [SensorManager] Initializing REAL hardware with Dynamic Port Discovery.");
      _discoverAndAssignPorts();
    } else {
      debugPrint(
          "🧪 [SensorManager] Initializing MOCK hardware for development.");
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
        _allDataController.add(
            SensorEvent(type: type, data: data, status: service.currentStatus));
      });
      service.statusStream.listen((status) {
        _allDataController.add(SensorEvent(type: type, status: status));
        if (status == SensorStatus.error ||
            status == SensorStatus.disconnected) {
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
        _allDataController.add(SensorEvent(
            type: SensorType.thermometer,
            data: tempData,
            status: hub.currentStatus));
      });
      hub.batteryStream.listen((voltage) {
        _allDataController.add(SensorEvent(
            type: SensorType.battery,
            data: voltage,
            status: hub.currentStatus));
        PowerManagerService().updateBatteryStatus(voltage);
      });
    }
  }

  Future<void> _discoverAndAssignPorts() async {
    final config = HardwareConfig.instance;
    final List<String> availablePorts = SerialPort.availablePorts;
    debugPrint(
        "🔍 [SensorManager] Scanning ${availablePorts.length} ports using dynamic config...");

    String? foundHubPort = config.hub.portOverride;
    String? foundOxiPort = config.oximeter.portOverride;
    String? foundBpPort = config.bloodPressure.portOverride;

    List<String> portsToScan = availablePorts
        .where(
            (p) => p != foundHubPort && p != foundOxiPort && p != foundBpPort)
        .toList();

    for (var portName in portsToScan) {
      if (foundHubPort != null && foundOxiPort != null && foundBpPort != null) break;
      
      debugPrint("📡 Probing $portName...");

      try {
        // 1. Probe for ESP32 Hub at 115200 baud
        if (foundHubPort == null && await _probePort(portName, config.hub.baudRate, config.hub.handshakeSignature, null, null)) {
          foundHubPort = portName;
          debugPrint("✅ Found ESP32 Hub on $portName");
          continue;
        }

        // 2. Probe for Oximeter at 19200 baud
        if (foundOxiPort == null && await _probePort(portName, config.oximeter.baudRate, null, config.oximeter.handshakeSignatureHex, null)) {
          foundOxiPort = portName;
          debugPrint("✅ Found Oximeter on $portName");
          continue;
        }

        // 3. Probe for Blood Pressure at 9600 baud
        if (foundBpPort == null && config.bloodPressure.handshakeSignature != null) {
          final query = Uint8List.fromList(config.bloodPressure.handshakeSignature!.codeUnits);
          if (await _probePort(portName, config.bloodPressure.baudRate, null, null, query)) {
            foundBpPort = portName;
            debugPrint("✅ Found Blood Pressure on $portName");
            continue;
          }
        }
      } catch (e) {
        debugPrint("⚠️ [SensorManager] Error probing $portName: $e");
      }
    }

    final String finalHub =
        foundHubPort ?? (Platform.isWindows ? 'COM1' : '/dev/ttyUSB0'); // ESP32 is usually USB0
    final String finalOxi =
        foundOxiPort ?? (Platform.isWindows ? 'COM2' : '/dev/ttyUSB1'); // Medical sensors follow
    final String finalBp =
        foundBpPort ?? (Platform.isWindows ? 'COM4' : '/dev/ttyUSB2');

    debugPrint(
        "✅ [SensorManager] Mapping: Hub=$finalHub, Oxi=$finalOxi, BP=$finalBp");

    _sensors[SensorType.weight] = SensorHubService(
        type: SensorType.weight,
        portName: finalHub,
        baudRate: config.hub.baudRate);
    _sensors[SensorType.thermometer] = SerialSensorService(
        type: SensorType.thermometer,
        portName: finalHub,
        baudRate: config.hub.baudRate);
    _sensors[SensorType.oximeter] = SerialSensorService(
        type: SensorType.oximeter,
        portName: finalOxi,
        baudRate: config.oximeter.baudRate);
    _sensors[SensorType.bloodPressure] = SerialSensorService(
        type: SensorType.bloodPressure,
        portName: finalBp,
        baudRate: config.bloodPressure.baudRate);

    // Explicitly map battery to the Hub service which provides the telemetry
    _sensors[SensorType.battery] = _sensors[SensorType.weight]!;
  }

  Future<bool> _probePort(String portName, int baudRate, String? asciiSig, String? hexSig, Uint8List? initCmd) async {
    final port = SerialPort(portName);
    bool matched = false;
    try {
      if (port.openReadWrite()) {
        port.config.baudRate = baudRate;
        final reader = SerialPortReader(port);
        final Completer<bool> comp = Completer();

        final sub = reader.stream.listen((data) {
          if (asciiSig != null && asciiSig.isNotEmpty) {
            if (String.fromCharCodes(data).contains(asciiSig)) {
              if (!comp.isCompleted) comp.complete(true);
            }
          } else if (hexSig != null && hexSig.isNotEmpty) {
            final sig = int.tryParse(hexSig, radix: 16);
            if (data.isNotEmpty && sig != null && data[0] == sig) {
              if (!comp.isCompleted) comp.complete(true);
            }
          } else if (initCmd != null) {
            // For devices that just reply to a command with anything
            if (data.isNotEmpty) {
               if (!comp.isCompleted) comp.complete(true);
            }
          }
        });

        if (initCmd != null) {
          port.write(initCmd);
        }

        matched = await comp.future.timeout(
          const Duration(milliseconds: 800), 
          onTimeout: () => false
        );
        
        sub.cancel();
      }
    } catch (_) {} finally {
      port.close();
    }
    return matched;
  }

  ISensorService getSensor(SensorType type) => 
      _sensors[type] ?? NullSensorService(type);

  ISensorService get weightSensor => getSensor(SensorType.weight);
  ISensorService get oximeterSensor => getSensor(SensorType.oximeter);
  ISensorService get thermometerSensor => getSensor(SensorType.thermometer);
  ISensorService get bpSensor => getSensor(SensorType.bloodPressure);
  ISensorService get batterySensor => getSensor(SensorType.battery);

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
      debugPrint(
          "📡 [SensorManager] Sending MSTR query to CONTEC BP monitor...");
      final query = Uint8List.fromList([0x4D, 0x53, 0x54, 0x52]);
      await bp.sendCommand(query);
    }
  }

  void _listenToPowerMode() {
    PowerManagerService().modeStream.listen((mode) {
      if (mode == PowerMode.deepSleep) {
        debugPrint(
            "🔋 [SensorManager] Deep Sleep: Stopping all sensor readings.");
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
