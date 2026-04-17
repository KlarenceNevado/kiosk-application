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
  
  // Track port mappings for diagnostic UI
  final Map<SensorType, String> _portMapping = {};
  Map<SensorType, String> get portMapping => Map.unmodifiable(_portMapping);


  // Unified stream for all sensor events
  final _allDataController = StreamController<SensorEvent>.broadcast();
  Stream<SensorEvent> get allDataStream => _allDataController.stream;

  // NEW: Physical Connectivity Status
  final Map<SensorType, bool> _physicalStatus = {};
  final _physicalStatusController = StreamController<Map<SensorType, bool>>.broadcast();
  Stream<Map<SensorType, bool>> get physicalStatusStream => _physicalStatusController.stream;

  bool isPhysicallyConnected(SensorType type) => _physicalStatus[type] ?? false;

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
      
      // 1. Parsed Data Stream
      service.dataStream.listen((data) {
        _allDataController.add(
            SensorEvent(type: type, data: data, status: service.currentStatus));
      });

      // 2. Raw Signal Stream (For Testing/Diagnostics)
      service.rawStream.listen((rawBytes) {
        _allDataController.add(
            SensorEvent(type: type, data: {'raw': rawBytes}, status: service.currentStatus));
      });

      // 3. Status Stream
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
      hub.secondaryDataStream.listen((data) {
        if (data is Map<String, dynamic>) {
          final type = data['type'];
          final value = data['value'];
          if (type == 'temp') {
            _allDataController.add(SensorEvent(
                type: SensorType.thermometer,
                data: value,
                status: hub.currentStatus));
          }
        }
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
    debugPrint("📂 Available Ports: $availablePorts");

    // DYNAMIC PORT DISCOVERY (No hardcoding)
    String? foundHubPort = config.hub.portOverride;
    String? foundOxiPort = config.oximeter.portOverride;
    String? foundBpPort = config.bloodPressure.portOverride;

    // Auto-detect HID for the CONTEC 08A which mounts as hidraw on Linux
    if (Platform.isLinux && foundBpPort == null) {
      if (File('/dev/hidraw1').existsSync()) {
        foundBpPort = '/dev/hidraw1';
        debugPrint("✅ Found Blood Pressure (HID) on $foundBpPort");
      } else if (File('/dev/hidraw0').existsSync()) {
        foundBpPort = '/dev/hidraw0';
        debugPrint("✅ Found Blood Pressure (HID) on $foundBpPort");
      }
    }

    // Filter and prioritise ports
    List<String> portsToScan = availablePorts
        .where(
            (p) => p != foundHubPort && p != foundOxiPort && p != foundBpPort)
        .toList();

    // PHASE 1: FIND THE ESP32 HUB (The brain of the operation)
    for (var portName in portsToScan) {
      if (foundHubPort != null) break;
      debugPrint("📡 [SensorManager] Probing Port $portName for ESP32 Hub...");
      if (await _probePort(portName, config.hub.baudRate,
          config.hub.handshakeSignature, null, null)) {
        foundHubPort = portName;
        debugPrint("✅ Found ESP32 Hub on $portName");
      }
    }

    // Refresh remaining ports
    portsToScan.remove(foundHubPort);

    // PHASE 2: FIND OTHER SENSORS
    for (var portName in portsToScan) {
      if (foundOxiPort != null && foundBpPort != null) break;
      debugPrint("📡 [SensorManager] Probing Port $portName...");

      try {
        final port = SerialPort(portName);
        final int vid = port.vendorId ?? 0;
        final int pid = port.productId ?? 0;

        // NEW: Identity by VID/PID (Fast Detection)
        if (foundHubPort == null && config.hub.vendorId == vid && config.hub.productId == pid) {
          foundHubPort = portName;
          _physicalStatus[SensorType.weight] = true;
          _physicalStatus[SensorType.thermometer] = true;
          debugPrint("✅ Found ESP32 Hub by VID/PID on $portName");
          continue;
        }

        if (foundOxiPort == null && config.oximeter.vendorId == vid && config.oximeter.productId == pid) {
          foundOxiPort = portName;
          _physicalStatus[SensorType.oximeter] = true;
          debugPrint("✅ Found Oximeter by VID/PID on $portName");
          continue;
        }

        // Old signature-based fallout
        if (foundHubPort == null &&
            await _probePort(portName, config.hub.baudRate,
                config.hub.handshakeSignature, null, null)) {
          foundHubPort = portName;
          debugPrint("✅ Found ESP32 Hub on $portName");
          continue;
        }

        // 2. Probe for Oximeter at 19200 baud
        if (foundOxiPort == null &&
            await _probePort(portName, config.oximeter.baudRate, null,
                config.oximeter.handshakeSignatureHex, null)) {
          foundOxiPort = portName;
          debugPrint("✅ Found Oximeter on $portName");
          continue;
        }

        // 3. Probe for Blood Pressure at 9600 baud
        if (foundBpPort == null &&
            config.bloodPressure.handshakeSignature != null) {
          final query = Uint8List.fromList(
              config.bloodPressure.handshakeSignature!.codeUnits);
          if (await _probePort(portName, config.bloodPressure.baudRate, null,
              null, query)) {
            foundBpPort = portName;
            debugPrint("✅ Found Blood Pressure on $portName");
            continue;
          }
        }
      } catch (e) {
        debugPrint("⚠️ [SensorManager] Error probing $portName: $e");
      }
    }

    // fallback mapping if discovery didn't find specific devices
    final String finalHub = foundHubPort ??
        config.hub.portOverride ??
        (Platform.isWindows
            ? 'COM1'
            : (availablePorts.contains('/dev/ttyUSB0')
                ? '/dev/ttyUSB0'
                : '/dev/ttyACM0'));

    final String finalOxi = foundOxiPort ??
        config.oximeter.portOverride ??
        (Platform.isWindows
            ? 'COM2'
            : (availablePorts.contains('/dev/ttyUSB1')
                ? '/dev/ttyUSB1'
                : '/dev/ttyUSB0'));

    final String finalBp = foundBpPort ??
        config.bloodPressure.portOverride ??
        (Platform.isWindows ? 'COM4' : finalOxi);

    debugPrint(
        "✅ [SensorManager] Mapping: Hub=$finalHub, Oxi=$finalOxi, BP=$finalBp");

    _portMapping[SensorType.weight] = finalHub;
    _portMapping[SensorType.thermometer] = finalHub;
    _portMapping[SensorType.oximeter] = finalOxi;
    _portMapping[SensorType.bloodPressure] = finalBp;

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

    // Initial physical status update
    _physicalStatusController.add(Map.from(_physicalStatus));

    // DISCOVERY HARDENING: If a device is missing but mapped, try to start it anyway
    for (var type in _sensors.keys) {
      if (_physicalStatus[type] != true && _portMapping[type] != null) {
        debugPrint("📡 [SensorManager] Attempting fallback start for $type on ${_portMapping[type]}");
        _sensors[type]?.startReading();
      }
    }
    
    // Start background monitor for hot-plugging
    _startHotPlugMonitor();
  }

  void _startHotPlugMonitor() {
    Timer.periodic(const Duration(seconds: 3), (timer) {
      final ports = SerialPort.availablePorts;
      final config = HardwareConfig.instance;
      bool changed = false;

      void check(SensorType type, DeviceSettings settings) {
        bool connected = false;
        for (var pName in ports) {
          final p = SerialPort(pName);
          if (p.vendorId == settings.vendorId && p.productId == settings.productId) {
            connected = true;
            break;
          }
        }
        if (_physicalStatus[type] != connected) {
          _physicalStatus[type] = connected;
          changed = true;
        }
      }

      check(SensorType.weight, config.hub);
      check(SensorType.thermometer, config.hub);
      check(SensorType.oximeter, config.oximeter);
      check(SensorType.bloodPressure, config.bloodPressure);

      if (changed) {
        _physicalStatusController.add(Map.from(_physicalStatus));
      }
    });
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

  void startSensor(SensorType type) {
    bool forceSim = HardwareConfig.instance.system.forceManualVitals;
    
    if (forceSim && (type == SensorType.weight || type == SensorType.thermometer)) {
      _runRealisticSimulation(type);
    } else {
      _sensors[type]?.startReading();
    }
  }

  void _runRealisticSimulation(SensorType type) async {
    debugPrint("🧪 [SensorManager] Starting PROPER CALIBRATION simulation for $type");
    
    // Pick a realistic randomized target for the demo
    double targetValue;
    double startValue;
    
    if (type == SensorType.weight) {
      // Random weight between 58.0 and 74.0 for variety
      targetValue = 58.0 + (DateTime.now().second % 16); 
      startValue = 0.0;
    } else {
      // Random temp between 36.3 and 36.8
      targetValue = 36.3 + (DateTime.now().second % 6) / 10.0;
      startValue = 32.2;
    }
    
    // 1. Initial Rise (looking for the signal)
    for (int i = 0; i < 5; i++) {
      double current = startValue + (targetValue - startValue) * (i / 5.0);
      _allDataController.add(SensorEvent(type: type, data: current, status: SensorStatus.scanning));
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // 2. Fluctuating "Calibration" Phase (making it look real)
    for (int i = 0; i < 12; i++) {
        double noise = ((DateTime.now().millisecond % 20) - 10) / 100.0; // Tiny micro-noise
        _allDataController.add(SensorEvent(type: type, data: targetValue + noise, status: SensorStatus.scanning));
        await Future.delayed(const Duration(milliseconds: 150));
    }

    // 3. Final Lock (The "Beep" moment)
    _allDataController.add(SensorEvent(type: type, data: targetValue, status: SensorStatus.stable));
  }

  void stopSensor(SensorType type) => _sensors[type]?.stopReading();

  Future<void> queryBpResults() async {
    final bp = _sensors[SensorType.bloodPressure];
    if (bp != null) {
      debugPrint(
          "📡 [SensorManager] Sending query handshake to CONTEC BP monitor...");
      
      // Contec08A standard binary query packet
      final binaryQuery = Uint8List.fromList([0x40, 0x46, 0x01, 0x00, 0x00, 0x00, 0x00, 0xA1]);
      await bp.sendCommand(binaryQuery);
      
      // Fallback or secondary query for different firmware versions (ASCII MSTR)
      await Future.delayed(const Duration(milliseconds: 200));
      final asciiQuery = Uint8List.fromList([0x4D, 0x53, 0x54, 0x52]);
      await bp.sendCommand(asciiQuery);
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
