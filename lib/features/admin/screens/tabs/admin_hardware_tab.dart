import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class AdminHardwareTab extends StatefulWidget {
  const AdminHardwareTab({super.key});

  @override
  State<AdminHardwareTab> createState() => _AdminHardwareTabState();
}

class _AdminHardwareTabState extends State<AdminHardwareTab> {
  bool _isCalibrating = false;
  double _calibrationProgress = 0.0;
  String _currentStatus = "All sensors operational";

  void _startCalibration(String sensorName) async {
    setState(() {
      _isCalibrating = true;
      _calibrationProgress = 0.0;
      _currentStatus = "Calibrating $sensorName...";
    });

    for (int i = 0; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _calibrationProgress = i / 10.0;
        });
      }
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
            "Manage and maintain kiosk-specific hardware components.",
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 32),
          if (_isCalibrating) ...[
            _buildCalibrationProgress(),
            const SizedBox(height: 32),
          ],
          _buildStatusCard(),
          const SizedBox(height: 32),
          const Text(
            "Sensor Maintenance",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildHardwareGrid(),
        ],
      ),
    );
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
            borderRadius: BorderRadius.circular(4),
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
