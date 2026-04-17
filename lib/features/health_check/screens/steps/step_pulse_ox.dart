import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../logic/health_wizard_provider.dart';
import '../../../../core/services/hardware/sensor_service_interface.dart';
import '../../../auth/domain/i_auth_repository.dart';

class StepPulseOx extends StatefulWidget {
  final VoidCallback onNext;
  const StepPulseOx({super.key, required this.onNext});

  @override
  State<StepPulseOx> createState() => _StepPulseOxState();
}

class _StepPulseOxState extends State<StepPulseOx>
    with TickerProviderStateMixin {
  int _viewState = 0; // 0=Prep, 1=Measuring, 2=Result, 3=Error
  Timer? _timeoutTimer;

  String _lockedHR = "--";
  String _lockedSpO2 = "--";

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  void _startMeasurement() {
    setState(() => _viewState = 1);
    final provider = context.read<HealthWizardProvider>();
    provider.startSensor(SensorType.oximeter);

    context.read<IAuthRepository>().resetSessionTimer();

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _viewState == 1) {
        setState(() => _viewState = 3); // Error State
      }
    });
  }

  void _finishTest(String hr, String spo2) {
    if (!mounted || _viewState == 2) return;
    _timeoutTimer?.cancel();
    context.read<HealthWizardProvider>().captureVital(SensorType.oximeter);
    context.read<IAuthRepository>().resetSessionTimer();

    setState(() {
      _viewState = 2;
      _lockedHR = hr;
      _lockedSpO2 = spo2;
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthWizardProvider>();

    // HARDENING: Auto-lock when stable OR Fast-Failure
    if (_viewState == 1) {
      final sStatus = provider.getSensorStatus(SensorType.oximeter);
      if (sStatus == SensorStatus.disconnected ||
          sStatus == SensorStatus.error) {
        Future.delayed(Duration.zero, () => setState(() => _viewState = 3));
      } else if (provider.isVitalStable(SensorType.oximeter) &&
          provider.currentSpO2 > 80 &&
          provider.currentHeartRate > 40) {
        Future.delayed(
            Duration.zero,
            () => _finishTest(provider.currentHeartRate.toString(),
                provider.currentSpO2.toString()));
      }
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
              color: AppColors.hrRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.hrRed.withValues(alpha: 0.2), width: 3)),
          child: const Icon(Icons.favorite_rounded,
              size: 72, color: AppColors.hrRed),
        ),
        const SizedBox(height: 32),
        const Text(
          "Step 5/7: Vital Signs",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: AppColors.brandDark,
              letterSpacing: -1.5),
        ),
        const SizedBox(height: 24),
        _buildInstructionCard(
            "Insert your index finger into the Pulse Oximeter clip.\nKeep your hand flat and still."),
        const SizedBox(height: 64),
        FlowAnimatedButton(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                    color: AppColors.hrRed.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10))
              ],
              gradient: const LinearGradient(
                  colors: [AppColors.hrRed, Color(0xFFD32F2F)]),
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
              child: const Text("Start Vital Measurement",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeasuringView(HealthWizardProvider provider) {
    bool isDone = _viewState == 2;
    bool isStable = provider.isVitalStable(SensorType.oximeter);
    String hrValue = isDone
        ? _lockedHR
        : (provider.currentHeartRate > 0
            ? provider.currentHeartRate.toString()
            : "READ");
    String spo2Value = isDone
        ? _lockedSpO2
        : (provider.currentSpO2 > 0 ? provider.currentSpO2.toString() : "READ");

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
                          : AppColors.hrRed.withValues(alpha: 0.12),
                      blurRadius: isDone ? 100 : 80,
                      spreadRadius: isDone ? 40 : 30)
                ],
              ),
            ),
            if (!isDone)
              ...List.generate(
                  2,
                  (index) => TweenAnimationBuilder(
                        duration: Duration(seconds: 1 + index),
                        tween: Tween<double>(begin: 1, end: 1.3),
                        builder: (context, val, child) => Container(
                          width: 270 * val,
                          height: 270 * val,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.hrRed
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
                color: isDone
                    ? AppColors.brandGreen
                    : (isStable ? AppColors.brandGreen : AppColors.hrRed),
                backgroundColor: AppColors.hrRed.withValues(alpha: 0.05),
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
                    ScaleTransition(
                      scale: Tween(begin: 1.0, end: 1.25).animate(
                          CurvedAnimation(
                              parent: _pulseController,
                              curve: Curves.easeInOut)),
                      child: Icon(Icons.favorite_rounded,
                          color:
                              isStable ? AppColors.brandGreen : AppColors.hrRed,
                          size: 48),
                    ),
                  const SizedBox(height: 8),
                  Text(hrValue,
                      style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: isDone
                              ? AppColors.brandGreen
                              : AppColors.brandDark,
                          height: 1.0,
                          letterSpacing: -3)),
                  const Text("HEART RATE (BPM)",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey,
                          letterSpacing: 1.0)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 56),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildRichMiniCard("OXYGEN LEVEL", spo2Value, "% SpO2",
                isStable ? AppColors.brandGreen : AppColors.spO2Cyan, isDone),
          ],
        ),
        const SizedBox(height: 48),
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
                    Text("Next Step",
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900)),
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
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
              ],
              border: Border.all(
                  color: isStable
                      ? AppColors.brandGreen.withValues(alpha: 0.2)
                      : AppColors.hrRed.withValues(alpha: 0.1),
                  width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color:
                            isStable ? AppColors.brandGreen : AppColors.hrRed)),
                const SizedBox(width: 16),
                Text(isStable ? "STABLE! HOLD..." : "STABILIZING READINGS...",
                    style: TextStyle(
                        color:
                            isStable ? AppColors.brandGreen : AppColors.hrRed,
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
        const Icon(Icons.signal_wifi_off_rounded,
            color: Colors.orange, size: 80),
        const SizedBox(height: 24),
        const Text("Unable to Detect Pulse",
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.brandDark)),
        const SizedBox(height: 16),
        const Text(
            "Ensure your finger is correctly inserted into the clip\nand keep your hand very still. If the problem persists,\nplease call a health worker for assistance.",
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
                  side: const BorderSide(color: AppColors.hrRed)),
              child: const Text("Retry Scan",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.hrRed)),
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: () {
                provider.setPulseOx(0, 0);
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

  Widget _buildRichMiniCard(
      String label, String value, String unit, Color color, bool isDone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDone
                ? AppColors.brandGreen.withValues(alpha: 0.2)
                : color.withValues(alpha: 0.2),
            width: 2.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDone ? AppColors.brandGreen : color,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: AppColors.brandDark,
                      letterSpacing: -2)),
              const SizedBox(width: 8),
              Text(unit,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey)),
            ],
          ),
        ],
      ),
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
              color: AppColors.hrRed.withValues(alpha: 0.1), width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 30,
                offset: const Offset(0, 10))
          ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: AppColors.hrRed, size: 36),
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
