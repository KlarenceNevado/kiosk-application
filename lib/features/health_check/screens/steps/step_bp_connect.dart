import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../logic/health_wizard_provider.dart';
import '../../../../core/services/hardware/sensor_service_interface.dart';
import '../../../auth/domain/i_auth_repository.dart';

class StepBpConnect extends StatefulWidget {
  final VoidCallback onNext;
  const StepBpConnect({super.key, required this.onNext});

  @override
  State<StepBpConnect> createState() => _StepBpConnectState();
}

class _StepBpConnectState extends State<StepBpConnect>
    with TickerProviderStateMixin {
  int _viewState = 0; // 0=Prep, 1=Measuring, 2=Result, 3=Error
  Timer? _timeoutTimer;
  String _lockedSys = "--";
  String _lockedDia = "--";

  late AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  void _startMeasurement() {
    setState(() => _viewState = 1);
    final provider = context.read<HealthWizardProvider>();
    provider.startSensor(SensorType.bloodPressure);

    context.read<IAuthRepository>().resetSessionTimer();

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _viewState == 1) {
        setState(() => _viewState = 3); // Error State
      }
    });
  }

  void _finishTest(String sys, String dia) {
    if (!mounted || _viewState == 2) return;
    _timeoutTimer?.cancel();
    context.read<HealthWizardProvider>().captureVital(SensorType.bloodPressure);
    context.read<IAuthRepository>().resetSessionTimer();

    setState(() {
      _viewState = 2;
      _lockedSys = sys;
      _lockedDia = dia;
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthWizardProvider>();

    // HARDENING: Auto-lock when result arrives
    if (_viewState == 1 &&
        provider.currentSystolic > 30 &&
        provider.currentDiastolic > 30) {
      Future.delayed(
          Duration.zero,
          () => _finishTest(provider.currentSystolic.toString(),
              provider.currentDiastolic.toString()));
    }

    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _viewState == 0
            ? _buildPrepView()
            : _viewState == 3
                ? _buildErrorView(provider)
                : _buildMeasuringView(provider),
      ),
    );
  }

  Widget _buildPrepView() {
    return Column(
      key: const ValueKey(0),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
              color: AppColors.bpBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.bpBlue.withValues(alpha: 0.2), width: 3)),
          child: const Icon(Icons.speed_rounded,
              size: 72, color: AppColors.bpBlue),
        ),
        const SizedBox(height: 32),
        const Text(
          "Step 6/7: Blood Pressure",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: AppColors.brandDark,
              letterSpacing: -1.5),
        ),
        const SizedBox(height: 24),
        _buildInstructionCard(
            "Place the cuff on your left arm and sit straight.\nRemain completely still until inflation stops."),
        const SizedBox(height: 64),
        FlowAnimatedButton(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                    color: AppColors.bpBlue.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10))
              ],
              gradient: const LinearGradient(
                  colors: [AppColors.bpBlue, Color(0xFF1976D2)]),
            ),
            child: ElevatedButton(
              onPressed: _startMeasurement,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(320, 72),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50))),
              child: const Text("Start BP Inflation",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeasuringView(HealthWizardProvider provider) {
    bool isDone = _viewState == 2;
    String sysVal = isDone
        ? _lockedSys
        : (provider.currentSystolic > 0
            ? provider.currentSystolic.toString()
            : "0");
    String diaVal = isDone
        ? _lockedDia
        : (provider.currentDiastolic > 0
            ? provider.currentDiastolic.toString()
            : "0");

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
                      color: isDone
                          ? AppColors.brandGreen.withValues(alpha: 0.2)
                          : AppColors.bpBlue.withValues(alpha: 0.12),
                      blurRadius: isDone ? 100 : 80,
                      spreadRadius: isDone ? 40 : 30)
                ],
              ),
            ),
            if (!isDone)
              ...List.generate(
                  3,
                  (index) => TweenAnimationBuilder(
                        duration: Duration(seconds: 1 + index),
                        tween: Tween<double>(begin: 1, end: 1.4),
                        builder: (context, val, child) => Container(
                          width: 270 * val,
                          height: 270 * val,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.bpBlue
                                      .withValues(alpha: 0.15 / val),
                                  width: 2)),
                        ),
                      )),
            SizedBox(
              width: 280,
              height: 280,
              child: CircularProgressIndicator(
                value: isDone ? 1 : null,
                strokeWidth: 14,
                strokeCap: StrokeCap.round,
                color: isDone ? AppColors.brandGreen : AppColors.bpBlue,
                backgroundColor: AppColors.bpBlue.withValues(alpha: 0.05),
              ),
            ),
            Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isDone)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.brandGreen, size: 60)
                  else
                    RotationTransition(
                      turns: Tween(begin: 0.0, end: 0.05).animate(
                          CurvedAnimation(
                              parent: _iconController,
                              curve: Curves.elasticIn)),
                      child: const Icon(Icons.speed_rounded,
                          color: AppColors.bpBlue, size: 48),
                    ),
                  const SizedBox(height: 8),
                  if (!isDone && provider.currentPressure > 0)
                    Text(provider.currentPressure.toString(),
                        style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.w900,
                            color: AppColors.bpBlue,
                            height: 1.0,
                            letterSpacing: -3))
                  else
                    Text("$sysVal/$diaVal",
                        style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: isDone
                                ? AppColors.brandGreen
                                : AppColors.brandDark,
                            height: 1.0,
                            letterSpacing: -3)),
                  Text(isDone ? "BP (mmHg)" : "INFLATING (mmHg)...",
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey,
                          letterSpacing: 1.0)),
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
                boxShadow: [
                  BoxShadow(
                      color: AppColors.brandGreen.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10))
                ],
                gradient: const LinearGradient(
                    colors: [AppColors.brandGreen, AppColors.brandGreenDark]),
              ),
              child: ElevatedButton(
                onPressed: widget.onNext,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(260, 72),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50))),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Complete Checkup",
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900)),
                    SizedBox(width: 12),
                    Icon(Icons.verified_rounded, size: 28),
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
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10)
              ],
              border: Border.all(
                  color: AppColors.bpBlue.withValues(alpha: 0.1), width: 2),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: AppColors.bpBlue)),
                SizedBox(width: 16),
                Text("INFLATING CUFF...",
                    style: TextStyle(
                        color: AppColors.bpBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.2)),
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
        const Icon(Icons.heart_broken_rounded, color: Colors.red, size: 80),
        const SizedBox(height: 24),
        const Text("Cuff Error",
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.brandDark)),
        const SizedBox(height: 16),
        const Text(
            "Ensure the cuff is tightened correctly and repeat. If the problem persists, please call a health worker for assistance.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey)),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _viewState = 0),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(180, 60),
                  side: const BorderSide(color: AppColors.bpBlue)),
              child: const Text("Retry BP",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.bpBlue)),
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: () {
                provider.setBloodPressure(0, 0);
                widget.onNext();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black87,
                  minimumSize: const Size(180, 60)),
              child: const Text("Skip Step",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: AppColors.bpBlue.withValues(alpha: 0.1), width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 30,
                offset: const Offset(0, 10))
          ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: AppColors.bpBlue, size: 36),
          const SizedBox(height: 16),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandDark,
                  height: 1.4)),
        ],
      ),
    );
  }
}
