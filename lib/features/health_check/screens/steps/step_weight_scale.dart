import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../logic/health_wizard_provider.dart';

class StepWeightScale extends StatefulWidget {
  final VoidCallback onNext;
  const StepWeightScale({super.key, required this.onNext});

  @override
  State<StepWeightScale> createState() => _StepWeightScaleState();
}

class _StepWeightScaleState extends State<StepWeightScale> {
  int _state = 0; // 0: Prep, 1: Measuring, 2: Done
  String _weightDisplay = "--.-";
  Timer? _weightTimer;

  void _startMeasurement() {
    setState(() => _state = 1);

    // Simulation
    double currentSimWeight = 40.0;
    double targetWeight = 70.0 + (Random().nextDouble() * 5);
    int ticks = 0;
    const int totalTicks = 30; // 3 seconds

    _weightTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      ticks++;

      setState(() {
        double progress = ticks / totalTicks;
        double noise = (Random().nextDouble() - 0.5) * 4.0 * (1 - progress);
        currentSimWeight = 40.0 + (targetWeight - 40.0) * progress + noise;
        _weightDisplay = currentSimWeight.toStringAsFixed(1);
      });

      if (ticks >= totalTicks) {
        timer.cancel();
        context
            .read<HealthWizardProvider>()
            .setWeight(double.parse(targetWeight.toStringAsFixed(1)));
        setState(() {
          _weightDisplay = targetWeight.toStringAsFixed(1);
          _state = 2;
        });
      }
    });
  }

  @override
  void dispose() {
    _weightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_state == 0) ...[
            const Icon(Icons.scale_rounded, size: 100, color: Colors.purple),
            const SizedBox(height: 32),
            const Text("Step 2: Weight",
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDark)),
            const SizedBox(height: 16),
            const Text(
                "Please stand on the platform scale now.\nRemove heavy shoes or bags.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Colors.grey)),
            const SizedBox(height: 60),
            FlowAnimatedButton(
              child: ElevatedButton(
                onPressed: _startMeasurement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 60, vertical: 24),
                ),
                child: const Text("Start Scale",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
          ] else ...[
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 280,
                  height: 280,
                  child: CircularProgressIndicator(
                    value: _state == 2 ? 1 : null,
                    strokeWidth: 15,
                    color: Colors.purple,
                    backgroundColor: Colors.purple.withValues(alpha: 0.1),
                  ),
                ),
                Column(
                  children: [
                    Text(_weightDisplay,
                        style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple)),
                    const Text("kg",
                        style: TextStyle(fontSize: 28, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 48),
            Text(_state == 2 ? "Measurement Complete" : "Measuring...",
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDark)),
            const SizedBox(height: 60),
            if (_state == 2)
              FlowAnimatedButton(
                child: ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 60, vertical: 24),
                  ),
                  child: const Text("Next: Temperature",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
          ]
        ],
      ),
    );
  }
}
