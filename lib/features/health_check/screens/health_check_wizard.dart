import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/routes.dart';
import '../logic/health_wizard_provider.dart';

// IMPORT STEPS
import 'steps/step_1_consent.dart';
import 'steps/step_height_input.dart';
import 'steps/step_weight_scale.dart';
import 'steps/step_3_sensor_scan.dart'; // Temperature
import 'steps/step_pulse_ox.dart'; // Pulse & Ox
import 'steps/step_bp_connect.dart'; // Blood Pressure
import 'steps/step_4_results.dart';

class HealthCheckWizard extends StatefulWidget {
  const HealthCheckWizard({super.key});

  @override
  State<HealthCheckWizard> createState() => _HealthCheckWizardState();
}

class _HealthCheckWizardState extends State<HealthCheckWizard> {
  late PageController _pageController;
  int _currentStep = 0;
  // 1.Consent, 2.Height, 3.Weight, 4.Temp, 5.PulseOx, 6.BP, 7.Results
  final int _totalSteps = 7;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<HealthWizardProvider>();
      provider.startHealthCheck();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _currentStep++);
  }

  void _safeExit() {
    context.read<HealthWizardProvider>().stopHealthCheck();
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _safeExit();
          }
        },
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon:
                  const Icon(Icons.close, color: AppColors.brandDark, size: 28),
              onPressed: _safeExit,
              tooltip: "Cancel Checkup",
            ),
            title: Text(
              "Health Check ${_currentStep + 1}/$_totalSteps",
              style: TextStyle(
                  color: AppColors.brandDark.withValues(alpha: 0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0),
            ),
            centerTitle: true,
          ),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF8FAF5),
                  Color(0xFFF0F4E8),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Premium Progress Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / _totalSteps,
                        minHeight: 10,
                        backgroundColor:
                            AppColors.brandGreen.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.brandGreen),
                      ),
                    ),
                  ),

                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        Step1Consent(onNext: _nextStep, onCancel: _safeExit),
                        StepHeightInput(onNext: _nextStep),
                        StepWeightScale(onNext: _nextStep),
                        Step3SensorScan(onNext: _nextStep),
                        StepPulseOx(onNext: _nextStep),
                        StepBpConnect(onNext: _nextStep),
                        const Step4Results(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
