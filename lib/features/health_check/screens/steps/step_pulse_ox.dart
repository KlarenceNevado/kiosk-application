import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../logic/health_wizard_provider.dart';

class StepPulseOx extends StatefulWidget {
  final VoidCallback onNext;
  const StepPulseOx({super.key, required this.onNext});

  @override
  State<StepPulseOx> createState() => _StepPulseOxState();
}

class _StepPulseOxState extends State<StepPulseOx> {
  int _state = 0;
  String _liveHR = "--";
  String _liveO2 = "--";
  Timer? _simTimer;

  void _startMeasurement() {
    setState(() => _state = 1);

    int ticks = 0;
    _simTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      ticks++;

      setState(() {
        // Fluctuate values to look "live"
        _liveHR = (70 + Random().nextInt(15)).toString();
        _liveO2 = (96 + Random().nextInt(3)).toString();
      });

      if (ticks >= 16) {
        // 4 seconds
        timer.cancel();
        setState(() => _state = 2);
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
    // Fallback to provider values if measurement done
    final hr = context.watch<HealthWizardProvider>().currentHeartRate;
    final spo2 = context.watch<HealthWizardProvider>().currentSpO2;

    final displayHR = _state == 2 && hr > 0 ? "$hr" : _liveHR;
    final displayO2 = _state == 2 && spo2 > 0 ? "$spo2" : _liveO2;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_state == 0) ...[
              const Icon(Icons.monitor_heart_rounded,
                  size: 100, color: Colors.red),
              const SizedBox(height: 32),
              const Text("Step 5: Pulse & Oxygen",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.touch_app_rounded, color: Colors.red),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Insert your index finger into the clip sensor. Relax your hand and keep it steady on the table.",
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
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                  ),
                  child: const Text("Start Measurement",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 8))
                    ]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(displayHR,
                              style: const TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red)),
                          const Text("BPM",
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold))
                        ],
                      ),
                    ),
                    Container(width: 2, height: 80, color: Colors.grey[200]),
                    Expanded(
                      child: Column(
                        children: [
                          Text(displayO2,
                              style: const TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyan)),
                          const Text("% SpO2",
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold))
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              if (_state == 1)
                const Text("Acquiring Signal...",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey))
              else
                const Text("Measurement Complete",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandGreen)),
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
                            borderRadius: BorderRadius.circular(50))),
                    child: const Text("Next: Blood Pressure",
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
