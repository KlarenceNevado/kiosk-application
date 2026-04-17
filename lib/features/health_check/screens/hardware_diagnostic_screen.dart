import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../../../core/services/hardware/sensor_manager.dart';
import '../../../core/services/hardware/sensor_service_interface.dart';
import 'dart:async';

class HardwareDiagnosticScreen extends StatefulWidget {
  const HardwareDiagnosticScreen({super.key});

  @override
  State<HardwareDiagnosticScreen> createState() => _HardwareDiagnosticScreenState();
}

class _HardwareDiagnosticScreenState extends State<HardwareDiagnosticScreen> {
  final SensorManager _sensorManager = SensorManager();
  StreamSubscription? _dataSubscription;
  final Map<SensorType, List<String>> _rawLogs = {};
  final Map<SensorType, Map<String, dynamic>> _lastReadings = {};
  final Map<SensorType, bool> _heartbeats = {};
  final List<String> _availablePorts = [];
  final Map<SensorType, bool> _physicalConnections = {};
  final Map<SensorType, int> _packetCounts = {};
  final Map<SensorType, DateTime> _lastUpdate = {};
  StreamSubscription? _physicalSubscription;

  @override
  void initState() {
    super.initState();
    _refreshPorts();
    _dataSubscription = _sensorManager.allDataStream.listen((event) {
      if (mounted) {
        setState(() {
          // Update Raw Logs
          _rawLogs.putIfAbsent(event.type, () => []);
          String logEntry = "[${DateTime.now().toIso8601String().split('T').last}] ${event.data}";
          _rawLogs[event.type]!.insert(0, logEntry);
          if (_rawLogs[event.type]!.length > 15) _rawLogs[event.type]!.removeLast();

          // Signal Integrity Tracking
          _packetCounts[event.type] = (_packetCounts[event.type] ?? 0) + 1;
          _lastUpdate[event.type] = DateTime.now();

          // Update Parsed Readings
          if (event.data is Map<String, dynamic>) {
            final map = event.data as Map<String, dynamic>;
            
            // Handle Raw Passthrough for the Terminal
            if (map.containsKey('raw')) {
              final rawBytes = map['raw'] as List<int>;
              _rawLogs.putIfAbsent(event.type, () => []);
              
              // NEW: Enhanced Hex/Text Log
              String hex = rawBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
              String text = String.fromCharCodes(rawBytes.where((b) => b > 31 && b < 127));
              String logEntry = "[RAW] $hex | $text";
              
              _rawLogs[event.type]!.insert(0, logEntry);
              if (_rawLogs[event.type]!.length > 20) _rawLogs[event.type]!.removeLast();
              
              // Trigger heartbeats even on raw noise
              _heartbeats[event.type] = true;
              Timer(const Duration(milliseconds: 150), () {
                if (mounted) setState(() => _heartbeats[event.type] = false);
              });
              return; 
            }

            _lastReadings[event.type] = map;
            
            // Trigger heartbeat animation for structured data
            _heartbeats[event.type] = true;
            Timer(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => _heartbeats[event.type] = false);
            });
          } else if (event.data != null) {
            // Primitive data (single numbers)
             _lastReadings[event.type] = {'value': event.data};
          }
        });
      }
    });

    _physicalSubscription = _sensorManager.physicalStatusStream.listen((statusMap) {
      if (mounted) {
        setState(() {
          _physicalConnections.clear();
          _physicalConnections.addAll(statusMap);
        });
      }
    });
  }

  void _refreshPorts() {
    setState(() {
      _availablePorts.clear();
      _availablePorts.addAll(SerialPort.availablePorts);
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _physicalSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hardware Diagnostics"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPorts,
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => _sensorManager.startAll(),
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: () => _sensorManager.stopAll(),
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar: Available Ports
          Container(
            width: 250,
            color: Colors.grey[200],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Available Ports", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _availablePorts.length,
                    itemBuilder: (context, index) {
                      final name = _availablePorts[index];
                      final port = SerialPort(name);
                      return ListTile(
                        dense: true,
                        title: Text(name),
                        subtitle: Text("ID: ${port.vendorId}:${port.productId}"),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Main Content: Sensor Status
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              children: SensorType.values.where((t) => t != SensorType.battery).map((type) {
                final port = _sensorManager.portMapping[type] ?? "Not Assigned";
                final sensor = _sensorManager.getSensor(type);
                final status = sensor.currentStatus;
                final logs = _rawLogs[type] ?? [];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(type.toString().split('.').last.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Row(
                              children: [
                                _PhysicalIndicator(isConnected: _physicalConnections[type] ?? false),
                                const SizedBox(width: 8),
                                _StatusIndicator(status: status),
                              ],
                            ),
                          ],
                        ),
                        Text("Port: $port", style: TextStyle(color: Colors.grey[600])),
                        const Divider(),
                        
                        // NEW: Live Signal Section
                        _LiveSignalIndicator(
                          type: type, 
                          data: _lastReadings[type], 
                          isPulsing: _heartbeats[type] ?? false,
                          packetCount: _packetCounts[type] ?? 0,
                          lastSeen: _lastUpdate[type],
                        ),
                        
                        const SizedBox(height: 8),
                        const Text("Recent Raw Data (Hex):", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ListView.builder(
                              itemCount: logs.length,
                              itemBuilder: (context, i) => Text(
                                logs[i],
                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 9, fontFamily: 'monospace'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => _sensorManager.startSensor(type),
                              child: const Text("Start"),
                            ),
                            const SizedBox(width: 8),
                            if (type == SensorType.weight)
                              ElevatedButton(
                                onPressed: () => sensor.calibrate(),
                                child: const Text("Tare"),
                              ),
                            if (type == SensorType.bloodPressure)
                              ElevatedButton(
                                onPressed: () => _sensorManager.queryBpResults(),
                                child: const Text("Ping"),
                              ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhysicalIndicator extends StatelessWidget {
  final bool isConnected;
  const _PhysicalIndicator({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.usb_rounded : Icons.usb_off_rounded,
            size: 14,
            color: isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            isConnected ? "NAKASAKSAK" : "HINDI NAKASAKSAK",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final SensorStatus status;
  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case SensorStatus.reading:
        color = Colors.green;
        break;
      case SensorStatus.connecting:
      case SensorStatus.scanning:
        color = Colors.orange;
        break;
      case SensorStatus.error:
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _LiveSignalIndicator extends StatelessWidget {
  final SensorType type;
  final Map<String, dynamic>? data;
  final bool isPulsing;

  final int packetCount;
  final DateTime? lastSeen;

  const _LiveSignalIndicator({
    required this.type,
    this.data,
    required this.isPulsing,
    required this.packetCount,
    this.lastSeen,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null && packetCount == 0) {
      return const Text("Waiting for hardware signal...", 
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12));
    }

    String display = "";
    IconData icon = Icons.sensors;
    Color iconColor = isPulsing ? Colors.red : Colors.grey;

    if (type == SensorType.oximeter) {
      display = "SpO2: ${data!['spo2']}%  BPM: ${data!['bpm']}";
      icon = Icons.favorite;
    } else if (type == SensorType.bloodPressure) {
      if (data!['type'] == 'realtime') {
        display = "Current Pressure: ${data!['pressure']} mmHg";
        icon = Icons.speed;
      } else if (data!['type'] == 'result') {
        display = "Last: ${data!['sys']}/${data!['dia']} BP (Pulse: ${data!['pulse']})";
        icon = Icons.check_circle;
        iconColor = Colors.green;
      }
    } else if (type == SensorType.weight) {
      display = "Weight: ${data!['weight']} kg";
      icon = Icons.monitor_weight;
    } else if (type == SensorType.thermometer) {
      display = "Temp: ${data!['temp']} °C";
      icon = Icons.thermostat;
    }

    return AnimatedScale(
      scale: isPulsing ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isPulsing ? Colors.red.withValues(alpha: 0.05) : Colors.blueGrey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isPulsing ? Colors.red.withValues(alpha: 0.2) : Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    display,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
                Text(
                  "#$packetCount",
                  style: const TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (lastSeen != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Active ${DateTime.now().difference(lastSeen!).inMilliseconds}ms ago",
                    style: const TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                  const Text(
                    "RAW SIGNAL OK",
                    style: TextStyle(fontSize: 8, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}
