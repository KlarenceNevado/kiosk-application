import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../logic/health_wizard_provider.dart';
import '../../../../core/services/hardware/sensor_service_interface.dart';
import '../../../../core/services/system/app_environment.dart';
import '../../../auth/domain/i_auth_repository.dart';

class Step3SensorScan extends StatefulWidget {
  final VoidCallback onNext;
  const Step3SensorScan({super.key, required this.onNext});

  @override
  State<Step3SensorScan> createState() => _Step3SensorScanState();
}

class _Step3SensorScanState extends State<Step3SensorScan> with TickerProviderStateMixin {
  // 0 = Prep, 1 = Measuring, 2 = Result
  int _viewState = 0;
  Timer? _simTimer;
  String _lockedTemp = "--.-";

  late AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  void _startScan() {
    setState(() => _viewState = 1);
    final provider = context.read<HealthWizardProvider>();
    provider.startSensor(SensorType.thermometer);
    
    // KEEP SESSION ALIVE
    context.read<IAuthRepository>().resetSessionTimer();

    if (!AppEnvironment().useSimulation) return;

    int ticks = 0;
    _simTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) { timer.cancel(); return; }
      ticks++;
      if (ticks >= 20) {
        timer.cancel();
        final finalTemp = 36.4 + (DateTime.now().millisecond % 10) / 10.0;
        provider.setTemperature(finalTemp);
        _finishTest(finalTemp.toStringAsFixed(1));
      }
    });
  }

  void _finishTest(String tempValue) {
    if (!mounted) return;
    context.read<HealthWizardProvider>().captureVital(SensorType.thermometer);
    context.read<IAuthRepository>().resetSessionTimer();
    
    setState(() {
      _viewState = 2;
      _lockedTemp = tempValue;
    });
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthWizardProvider>();
    final isSim = AppEnvironment().useSimulation;

    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _viewState == 0 
            ? _buildPrepView() 
            : _buildMeasuringView(provider, isSim),
      ),
    );
  }

  Widget _buildPrepView() {
    return Column(
      key: const ValueKey(0),
      mainAxisAlignment: MainAxisAlignment.center, // STRICT CENTER
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
              color: AppColors.tempOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.tempOrange.withValues(alpha: 0.2), width: 3)),
          child: const Icon(Icons.thermostat_rounded, size: 72, color: AppColors.tempOrange),
        ),
        const SizedBox(height: 32),
        const Text(
          "Step 4/7: Temperature Scan",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppColors.brandDark, letterSpacing: -1.5),
        ),
        const SizedBox(height: 24),
        _buildInstructionCard("Position your forehead exactly 5cm from the sensor.\nRemove hair, glasses, or hats."),
        const SizedBox(height: 64),
        FlowAnimatedButton(
          child: Container(
            decoration: BoxDecoration(
               borderRadius: BorderRadius.circular(50),
               boxShadow: [BoxShadow(color: AppColors.tempOrange.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
               gradient: const LinearGradient(colors: [AppColors.tempOrange, Color(0xFFFB8C00)]),
            ),
            child: ElevatedButton(
              onPressed: _startScan,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(320, 72),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
              child: const Text("Start Temperature Scan", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeasuringView(HealthWizardProvider provider, bool isSim) {
    bool isDone = _viewState == 2;
    String displayTemp = isDone ? _lockedTemp : (isSim ? "--.-" : (provider.currentTemp > 0 ? provider.currentTemp.toStringAsFixed(1) : "SCANNING"));

    return Column(
      key: const ValueKey(1),
      mainAxisAlignment: MainAxisAlignment.center, // STRICT CENTER
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // THE PREMIUM GLOW (Bloom)
            AnimatedContainer(
                 duration: const Duration(milliseconds: 500),
                 width: isDone ? 340 : 300, 
                 height: isDone ? 340 : 300,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   boxShadow: [
                     BoxShadow(
                        color: isDone ? AppColors.brandGreen.withValues(alpha: 0.2) : AppColors.tempOrange.withValues(alpha: 0.12), 
                        blurRadius: isDone ? 100 : 80, 
                        spreadRadius: isDone ? 40 : 30
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
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.tempOrange.withValues(alpha: 0.15 / val), width: 2),
                  ),
                ),
              )),
            
            SizedBox(
              width: 280, height: 280,
              child: CircularProgressIndicator(
                value: isDone ? 1 : null,
                strokeWidth: 14,
                strokeCap: StrokeCap.round,
                color: isDone ? AppColors.brandGreen : AppColors.tempOrange,
                backgroundColor: AppColors.tempOrange.withValues(alpha: 0.05),
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
                    FadeTransition(
                      opacity: Tween(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _iconController, curve: Curves.easeInOut)),
                      child: const Icon(Icons.thermostat_rounded, color: AppColors.tempOrange, size: 48),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(displayTemp, style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: isDone ? AppColors.brandGreen : AppColors.brandDark, height: 1.0, letterSpacing: -2)),
                      const SizedBox(width: 4),
                      const Text("°C", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.grey)),
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
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
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
               color: Colors.white, 
               borderRadius: BorderRadius.circular(50),
               boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
               border: Border.all(color: AppColors.tempOrange.withValues(alpha: 0.1), width: 2),
            ),
            child: const Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.tempOrange)),
                 SizedBox(width: 16),
                 Text("STABILIZING READINGS...", style: TextStyle(color: AppColors.tempOrange, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
               ],
            ),
          ),
      ],
    );
  }

  Widget _buildInstructionCard(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.tempOrange.withValues(alpha: 0.1), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 30, offset: const Offset(0, 10))]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: AppColors.tempOrange, size: 36),
          const SizedBox(height: 16),
          Text(
            text, 
            textAlign: TextAlign.center, // CENTER TEXT
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.brandDark, height: 1.4)
          ),
        ],
      ),
    );
  }
}
