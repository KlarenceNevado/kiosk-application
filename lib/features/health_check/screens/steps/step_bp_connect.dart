import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../logic/health_wizard_provider.dart';
import '../../../../core/services/hardware/sensor_service_interface.dart';


class StepBpConnect extends StatefulWidget {
  final VoidCallback onNext;
  const StepBpConnect({super.key, required this.onNext});

  @override
  State<StepBpConnect> createState() => _StepBpConnectState();
}

class _StepBpConnectState extends State<StepBpConnect> {
  int _state = 0; // 0: Prep, 1: Inflating, 2: Measuring, 3: Done
  int _cuffPressure = 0;
  Timer? _simTimer;

  void _startMeasurement() {
    setState(() => _state = 1);
    context.read<HealthWizardProvider>().startSensor(SensorType.bloodPressure);

    // Simulate Inflation (0 -> 160)
    _simTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cuffPressure < 170) {
        setState(() => _cuffPressure += 4);
      } else {
        timer.cancel();
        _deflate();
      }
    });
  }

  void _deflate() {
    setState(() => _state = 2);
    // Simulate Deflation (170 -> 118)
    _simTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cuffPressure > 118) {
        setState(() => _cuffPressure -= 2);
      } else {
        timer.cancel();
        setState(() => _state = 3);
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
    final sys = context.watch<HealthWizardProvider>().currentSystolic;
    final dia = context.watch<HealthWizardProvider>().currentDiastolic;

    // Use simulated pressure during measurement, actual values when done
    final displayValue = _state == 3 ? "$sys / $dia" : "$_cuffPressure";
    final displayLabel = _state == 3 ? "mmHg" : "Cuff Pressure";

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_state == 0) ...[
              const Icon(Icons.speed_rounded, size: 100, color: Colors.blue),
              const SizedBox(height: 32),
              const Text("Step 6: Blood Pressure",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.front_hand_rounded,
                        color: Colors.blue), // Wrist icon
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Wear the cuff on your LEFT wrist. Keep your arm relaxed at heart level. Do not move or talk.",
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
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                  ),
                  child: const Text("Start Inflation",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ] else ...[
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: CircularProgressIndicator(
                        value: _state == 3
                            ? 1.0
                            : (_cuffPressure / 180).clamp(0.0, 1.0),
                        strokeWidth: 15,
                        color: Colors.blue,
                        backgroundColor: Colors.blue.withValues(alpha: 0.1)),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(displayValue,
                          style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue)),
                      Text(displayLabel,
                          style: const TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Text(
                  _state == 1
                      ? "Inflating..."
                      : _state == 2
                          ? "Measuring..."
                          : "Complete",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _state == 3 ? AppColors.brandGreen : Colors.grey)),
              const SizedBox(height: 60),
              if (_state == 3)
                FlowAnimatedButton(
                  child: ElevatedButton(
                    onPressed: widget.onNext,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 60, vertical: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50))),
                    child: const Text("View Results",
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
