import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../logic/health_wizard_provider.dart';
import '../../../../core/services/hardware/sensor_service_interface.dart';


class Step3SensorScan extends StatefulWidget {
  final VoidCallback onNext;
  const Step3SensorScan({super.key, required this.onNext});

  @override
  State<Step3SensorScan> createState() => _Step3SensorScanState();
}

class _Step3SensorScanState extends State<Step3SensorScan> {
  // 0: Instruction, 1: Scanning, 2: Result
  int _state = 0;
  String _liveDisplay = "--.-";
  Timer? _simTimer;

  void _startMeasurement() {
    setState(() => _state = 1);
    context.read<HealthWizardProvider>().startSensor(SensorType.thermometer);

    // Simulate finding the temp
    double currentSimTemp = 34.0;
    double targetTemp = 36.5 + (Random().nextDouble() * 0.5);
    int ticks = 0;
    const int totalTicks = 20; // 2 seconds (IR is fast)

    _simTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      ticks++;

      setState(() {
        // Smoothly approach target
        currentSimTemp += (targetTemp - currentSimTemp) * 0.2;
        _liveDisplay = currentSimTemp.toStringAsFixed(1);
      });

      if (ticks >= totalTicks) {
        timer.cancel();
        // Set final state
        if (mounted) setState(() => _state = 2);
      }
    });
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get actual value from provider if available
    final temp = context.watch<HealthWizardProvider>().currentTemp;
    final displayTemp =
        _state == 2 && temp > 0 ? temp.toStringAsFixed(1) : _liveDisplay;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- STATE 0: INSTRUCTION ---
            if (_state == 0) ...[
              const Icon(Icons.thermostat, size: 100, color: Colors.orange),
              const SizedBox(height: 32),
              const Text("Step 4: Body Temperature",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark)),
              const SizedBox(height: 24),

              // Instruction Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Position your forehead about 5cm (2 inches) away from the sensor. Remove hats or hair covering the forehead.",
                        style: TextStyle(
                            fontSize: 18, height: 1.4, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              FlowAnimatedButton(
                child: ElevatedButton(
                  onPressed: _startMeasurement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                  ),
                  child: const Text("Start Scan",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ]

            // --- STATE 1 & 2: MEASURING & RESULT ---
            else ...[
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: CircularProgressIndicator(
                        value: _state == 2 ? 1 : null,
                        strokeWidth: 12,
                        color: Colors.orange,
                        backgroundColor: Colors.orange.withValues(alpha: 0.1)),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(displayTemp,
                          style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                      const Text("°C",
                          style: TextStyle(
                              fontSize: 24,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 48),
              Text(_state == 2 ? "Reading Captured" : "Scanning...",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _state == 2
                          ? AppColors.brandGreen
                          : AppColors.brandDark)),
              const SizedBox(height: 60),
              if (_state == 2)
                FlowAnimatedButton(
                  child: ElevatedButton(
                    onPressed: widget.onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandGreen,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 60, vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50)),
                    ),
                    child: const Text("Next: Pulse & Oxygen",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
            ]
          ],
        ),
      ),
    );
  }
}
