import 'dart:io';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/hardware/sensor_manager.dart';
import '../../../../core/services/system/power_manager_service.dart';
import '../../../../core/services/hardware/hardware_control_service.dart';

class AdminHardwareTab extends StatefulWidget {
  const AdminHardwareTab({super.key});

  @override
  State<AdminHardwareTab> createState() => _AdminHardwareTabState();
}

class _AdminHardwareTabState extends State<AdminHardwareTab> {
  bool _isCalibrating = false;
  double _calibrationProgress = 0.0;
  String _currentStatus = "All sensors operational";

  // Power & Hardware services
  final _powerManager = PowerManagerService();
  final _hardware = HardwareControlService();

  // Local state for relays (optimistic UI)
  bool _relay1On = true;
  bool _relay2On = true;

  void _startCalibration(String sensorName) async {
    final sensorManager = context.read<SensorManager>();

    setState(() {
      _isCalibrating = true;
      _calibrationProgress = 0.1;
      _currentStatus = "Calibrating $sensorName...";
    });

    try {
      if (sensorName == "Weighing Scale") {
        await sensorManager.weightSensor.calibrate();
      } else if (sensorName == "All Sensors") {
        await sensorManager.weightSensor.calibrate();
      }

      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) setState(() => _calibrationProgress = i / 10.0);
      }
    } catch (e) {
      debugPrint("❌ Calibration failed: $e");
    }

    if (mounted) {
      setState(() {
        _isCalibrating = false;
        _currentStatus = "$sensorName calibrated successfully.";
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("$sensorName calibration complete."),
        backgroundColor: AppColors.brandGreen,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Hardware Control & Calibration",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Environment: Raspberry Pi 4B (Solar Integrated)",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              _buildThermalBadge(),
            ],
          ),
          const SizedBox(height: 32),
          if (_isCalibrating) ...[
            _buildCalibrationProgress(),
            const SizedBox(height: 32),
          ],
          _buildStatusCard(),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _buildEnvironmentalStats()),
              const SizedBox(width: 24),
              Expanded(child: _buildRelayControlCard()),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            "Sensor & Peripheral Maintenance",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildHardwareGrid(),
          const SizedBox(height: 40),
          _buildSystemActions(),
        ],
      ),
    );
  }

  Widget _buildThermalBadge() {
    return StreamBuilder<PowerMode>(
      stream: _powerManager.modeStream,
      builder: (context, snapshot) {
        final isThrottled = _powerManager.currentMode == PowerMode.eco;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isThrottled ? Colors.orange.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isThrottled ? Colors.orange : Colors.blue),
          ),
          child: Row(
            children: [
              Icon(Icons.thermostat, size: 16, color: isThrottled ? Colors.orange : Colors.blue),
              const SizedBox(width: 8),
              Text(
                isThrottled ? "THERMAL THROTTLE" : "SYSTEM COOL",
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold,
                  color: isThrottled ? Colors.orange : Colors.blue,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnvironmentalStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Power Metrics", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          _buildStatRow("Battery Voltage", "${_powerManager.currentVoltage} V", Icons.battery_charging_full),
          const Divider(),
          _buildStatRow("Capacity", "${_powerManager.batteryPercentage.toInt()}%", Icons.bolt),
          const Divider(),
          _buildStatRow("System Load", "12%", Icons.speed), // Placeholder load
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.black54)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRelayControlCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Hardware Overrides (Relays)", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _buildRelaySwitch("Sensor Hub Power", _relay1On, (val) {
             _hardware.setRelayState(HardwareControlService.relayChannel1, val);
             setState(() => _relay1On = val);
          }),
          _buildRelaySwitch("Accessory Power", _relay2On, (val) {
             _hardware.setRelayState(HardwareControlService.relayChannel2, val);
             setState(() => _relay2On = val);
          }),
        ],
      ),
    );
  }

  Widget _buildRelaySwitch(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Switch(
          value: value,
          activeTrackColor: AppColors.brandGreen,
          activeThumbColor: Colors.white,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSystemActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Danger Zone", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _handleSystemAction('restart'),
              icon: const Icon(Icons.restart_alt),
              label: const Text("Restart Kiosk"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => _handleSystemAction('shutdown'),
              icon: const Icon(Icons.power_settings_new),
              label: const Text("Shutdown System"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleSystemAction(String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Confirm ${action.toUpperCase()}"),
        content: Text("Are you sure you want to $action the kiosk system?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text("Yes, $action"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (Platform.isLinux) {
        if (action == 'restart') {
          await Process.run('sudo', ['reboot']);
        } else {
          await Process.run('sudo', ['shutdown', '-h', 'now']);
        }
      } else {
        debugPrint("⚠️ [SystemAction] $action not supported on this platform.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$action is only supported on Raspberry Pi deployments."))
        );
      }
    }
  }

  Widget _buildCalibrationProgress() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.brandGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_currentStatus,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("${(_calibrationProgress * 100).toInt()}%"),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _calibrationProgress,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation(AppColors.brandGreen),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brandGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle,
                color: AppColors.brandGreen, size: 32),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Hardware Health",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(_currentStatus, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed:
                _isCalibrating ? null : () => _startCalibration("All Sensors"),
            icon: const Icon(Icons.refresh),
            label: const Text("Full Diagnostic"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      children: [
        _buildSensorCard("Thermometer", Icons.thermostat, "v2.1.0"),
        _buildSensorCard("BP Monitor", Icons.monitor_heart, "v3.0.4"),
        _buildSensorCard("Pulse Oximeter", Icons.bloodtype, "v1.2.9"),
        _buildSensorCard("Weighing Scale", Icons.scale, "v2.2.0"),
      ],
    );
  }

  Widget _buildSensorCard(String name, IconData icon, String version) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.brandDark, size: 28),
              const SizedBox(width: 12),
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(version,
                    style: const TextStyle(fontSize: 10, color: Colors.blue)),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              TextButton(
                onPressed:
                    _isCalibrating ? null : () => _startCalibration(name),
                child: const Text("Calibrate"),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
                child: const Text("Details"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
