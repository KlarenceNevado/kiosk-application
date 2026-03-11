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

    // Initialize Hardware
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HealthWizardProvider>().startHealthCheck();
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
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: _safeExit,
              tooltip: "Cancel Checkup",
            ),
            title: Text(
              "Health Check ${_currentStep + 1}/$_totalSteps",
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              // Progress Bar
              LinearProgressIndicator(
                value: (_currentStep + 1) / _totalSteps,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.brandGreen),
              ),

              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics:
                      const NeverScrollableScrollPhysics(), // Prevent swipe, force buttons
                  children: [
                    Step1Consent(onNext: _nextStep, onCancel: _safeExit),
                    StepHeightInput(onNext: _nextStep),
                    StepWeightScale(onNext: _nextStep),
                    Step3SensorScan(onNext: _nextStep), // Temperature
                    StepPulseOx(onNext: _nextStep), // Pulse & Ox
                    StepBpConnect(onNext: _nextStep), // Blood Pressure
                    const Step4Results(),
                  ],
                ),
              ),

              // Debug Skip (Remove in production)
              if (_currentStep > 0 && _currentStep < 6)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextButton(
                    onPressed: _nextStep,
                    child: const Text("Dev Skip >",
                        style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ),
                )
            ],
          ),
        ));
  }
}
