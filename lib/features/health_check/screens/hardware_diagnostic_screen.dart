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

          // Update Parsed Readings
          if (event.data is Map<String, dynamic>) {
            _lastReadings[event.type] = event.data as Map<String, dynamic>;
            
            // Trigger heartbeat animation
            _heartbeats[event.type] = true;
            Timer(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => _heartbeats[event.type] = false);
            });
          }
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
                            _StatusIndicator(status: status),
                          ],
                        ),
                        Text("Port: $port", style: TextStyle(color: Colors.grey[600])),
                        const Divider(),
                        
                        // NEW: Live Signal Section
                        _LiveSignalIndicator(
                          type: type, 
                          data: _lastReadings[type], 
                          isPulsing: _heartbeats[type] ?? false
                        ),
                        
                        const SizedBox(height: 8),
                        const Text("Recent Raw Data:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
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

  const _LiveSignalIndicator({
    required this.type,
    this.data,
    required this.isPulsing,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return const Text("Waiting for data signal...", 
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
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                display,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
