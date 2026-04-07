import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../logic/health_wizard_provider.dart';
import '../../../../core/services/hardware/sensor_service_interface.dart';
import '../../../../core/services/system/app_environment.dart';
import '../../../auth/domain/i_auth_repository.dart';

class StepWeightScale extends StatefulWidget {
  final VoidCallback onNext;
  const StepWeightScale({super.key, required this.onNext});

  @override
  State<StepWeightScale> createState() => _StepWeightScaleState();
}

class _StepWeightScaleState extends State<StepWeightScale> with TickerProviderStateMixin {
  int _viewState = 0; // 0=Prep, 1=Measuring, 2=Result, 3=Error
  Timer? _simTimer;
  Timer? _timeoutTimer;
  String _lockedWeight = "--.-";

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  void _startMeasurement() {
    setState(() => _viewState = 1);
    final provider = context.read<HealthWizardProvider>();
    provider.startSensor(SensorType.weight);
    
    context.read<IAuthRepository>().resetSessionTimer();

    // HARDENING: Safety Timeout
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _viewState == 1) {
        setState(() => _viewState = 3); // Error State
      }
    });

    if (!AppEnvironment().useSimulation) return;

    int ticks = 0;
    double targetWeight = 62.5 + Random().nextDouble() * 5;
    _simTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) { timer.cancel(); return; }
      ticks++;
      if (ticks >= 25) {
        timer.cancel();
        provider.setWeight(targetWeight);
        // Step logic will auto-detect stability from provider via listener
      }
    });
  }

  void _finishTest(String weight) {
    if (!mounted || _viewState == 2) return;
    _timeoutTimer?.cancel();
    context.read<HealthWizardProvider>().captureVital(SensorType.weight);
    context.read<IAuthRepository>().resetSessionTimer();
    
    setState(() {
      _viewState = 2;
      _lockedWeight = weight;
    });
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _timeoutTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthWizardProvider>();
    final isSim = AppEnvironment().useSimulation;

    // HARDENING: Auto-lock when stable OR Fast-Failure if hardware disconnects
    if (_viewState == 1) {
      final sStatus = provider.getSensorStatus(SensorType.weight);
      if (sStatus == SensorStatus.disconnected || sStatus == SensorStatus.error) {
         Future.delayed(Duration.zero, () => setState(() => _viewState = 3));
      } else if (provider.isVitalStable(SensorType.weight) && provider.weightKg > 5.0) {
        Future.delayed(Duration.zero, () => _finishTest(provider.weightKg.toStringAsFixed(1)));
      }
    }

    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _viewState == 0 
            ? _buildPrepView() 
            : _viewState == 3 ? _buildErrorView(provider) : _buildMeasuringView(provider, isSim),
      ),
    );
  }

  Widget _buildPrepView() {
    return Column(
      key: const ValueKey(0),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.purple.withValues(alpha: 0.2), width: 3)),
          child: const Icon(Icons.scale_rounded, size: 72, color: Colors.purple),
        ),
        const SizedBox(height: 32),
        const Text(
          "Step 3/7: Body Weight",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppColors.brandDark, letterSpacing: -1.0),
        ),
        const SizedBox(height: 24),
        _buildInstructionCard("Stand consistently on the platform scale.\nRemain still until the scan completes."),
        const SizedBox(height: 64),
        FlowAnimatedButton(
          child: Container(
            decoration: BoxDecoration(
               borderRadius: BorderRadius.circular(50),
               boxShadow: [BoxShadow(color: Colors.purple.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
               gradient: const LinearGradient(colors: [Colors.purple, Color(0xFF9C27B0)]),
            ),
            child: ElevatedButton(
              onPressed: _startMeasurement,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, foregroundColor: Colors.white, shadowColor: Colors.transparent,
                  minimumSize: const Size(320, 72),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
              child: const Text("Start Measurement", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeasuringView(HealthWizardProvider provider, bool isSim) {
    bool isDone = _viewState == 2;
    bool isStable = provider.isVitalStable(SensorType.weight);
    String displayWeight = isDone ? _lockedWeight : (provider.weightKg > 0 ? provider.weightKg.toStringAsFixed(1) : "0.0");

    return Column(
      key: const ValueKey(1),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
                 duration: const Duration(milliseconds: 500),
                 width: isDone ? 340 : 300, 
                 height: isDone ? 340 : 300,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   boxShadow: [
                     BoxShadow(
                        color: isDone ? AppColors.brandGreen.withValues(alpha: 0.2) : Colors.purple.withValues(alpha: 0.12), 
                        blurRadius: isDone ? 100 : 80, spreadRadius: isDone ? 40 : 30
                     )
                   ],
                 ),
               ),

            if (!isDone)
              ...List.generate(2, (index) => TweenAnimationBuilder(
                duration: Duration(seconds: 1 + index),
                tween: Tween<double>(begin: 1, end: 1.3),
                builder: (context, val, child) => Container(
                  width: 270 * val, height: 270 * val,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.purple.withValues(alpha: 0.15 / val), width: 2)),
                ),
              )),
            
            SizedBox(
              width: 280, height: 280,
              child: CircularProgressIndicator(
                value: isDone ? 1 : null,
                strokeWidth: 14, strokeCap: StrokeCap.round,
                color: isDone ? AppColors.brandGreen : (isStable ? AppColors.brandGreen : Colors.purple),
                backgroundColor: Colors.purple.withValues(alpha: 0.05),
              ),
            ),

            Container(
              width: 220, height: 220,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isDone)
                    const Icon(Icons.check_circle_rounded, color: AppColors.brandGreen, size: 64)
                  else
                    ScaleTransition(
                      scale: Tween(begin: 0.9, end: 1.1).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                      child: Icon(Icons.scale_rounded, color: isStable ? AppColors.brandGreen : Colors.purple, size: 48),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(displayWeight, style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: isDone ? AppColors.brandGreen : AppColors.brandDark, height: 1.0, letterSpacing: -2)),
                      const SizedBox(width: 4),
                      const Text("kg", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 64),
        if (isDone)
          FlowAnimatedButton(
            child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 16),
               decoration: BoxDecoration(
                 borderRadius: BorderRadius.circular(50),
                 boxShadow: [BoxShadow(color: AppColors.brandGreen.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
                 gradient: const LinearGradient(colors: [AppColors.brandGreen, AppColors.brandGreenDark]),
               ),
               child: ElevatedButton(
                 onPressed: widget.onNext,
                 style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent, foregroundColor: Colors.white, shadowColor: Colors.transparent,
                    minimumSize: const Size(260, 72),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                 child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Next Step", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      SizedBox(width: 12),
                      Icon(Icons.arrow_forward_rounded, size: 28),
                    ],
                 ),
               ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
               color: Colors.white, borderRadius: BorderRadius.circular(50),
               boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
               border: Border.all(color: isStable ? AppColors.brandGreen.withValues(alpha: 0.2) : Colors.purple.withValues(alpha: 0.1), width: 2),
            ),
            child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 3, color: isStable ? AppColors.brandGreen : Colors.purple)),
                 const SizedBox(width: 16),
                 Text(isStable ? "STABLE! HOLD..." : "STABILIZING WEIGHT...", style: TextStyle(color: isStable ? AppColors.brandGreen : Colors.purple.withValues(alpha: 0.8), fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
               ],
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView(HealthWizardProvider provider) {
    return Column(
      key: const ValueKey(3),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 80),
        const SizedBox(height: 24),
        const Text("Sensor Not Responding", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
        const SizedBox(height: 16),
        const Text("The scale is taking too long to stabilize.", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey)),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _viewState = 0),
              style: OutlinedButton.styleFrom(minimumSize: const Size(180, 60), side: const BorderSide(color: Colors.purple)),
              child: const Text("Retry Scan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple)),
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: () {
                provider.setWeight(0.0); // Allow skipping if broken
                widget.onNext();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black87, minimumSize: const Size(180, 60)),
              child: const Text("Skip Step", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstructionCard(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.1), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 30, offset: const Offset(0, 10))]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: Colors.purple, size: 36),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.brandDark, height: 1.4)),
        ],
      ),
    );
  }
}
