import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../../../core/services/hardware/sensor_manager.dart';
import '../../../core/services/hardware/sensor_service_interface.dart';
import '../../../core/services/hardware/sensor_data_models.dart';
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
  final List<String> _availablePorts = [];

  @override
  void initState() {
    super.initState();
    _refreshPorts();
    _dataSubscription = _sensorManager.allDataStream.listen((event) {
      setState(() {
        _rawLogs.putIfAbsent(event.type, () => []);
        String logEntry = "[${DateTime.now().toIso8601String().split('T').last}] ${event.data}";
        _rawLogs[event.type]!.insert(0, logEntry);
        if (_rawLogs[event.type]!.length > 20) _rawLogs[event.type]!.removeLast();
      });
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
                        const Text("Recent Data:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ListView.builder(
                              itemCount: logs.length,
                              itemBuilder: (context, i) => Text(
                                logs[i],
                                style: const TextStyle(color: Colors.green, fontSize: 10, fontFamily: 'monospace'),
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
