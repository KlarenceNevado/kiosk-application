import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

// CORE
import '../../../../core/constants/app_colors.dart';
import '../../../../core/config/routes.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../../../core/widgets/vital_sign_display.dart';
import '../../../../core/utils/vital_validator.dart';

// LOGIC & DATA
import '../../logic/health_wizard_provider.dart';
import '../../../user_history/domain/i_history_repository.dart';
import '../../../auth/domain/i_auth_repository.dart';
import '../../../../core/services/database/sync_service.dart';

class Step4Results extends StatefulWidget {
  const Step4Results({super.key});

  @override
  State<Step4Results> createState() => _Step4ResultsState();
}

class _Step4ResultsState extends State<Step4Results>
    with SingleTickerProviderStateMixin {
  bool _isSaving = false;
  late AnimationController _animationController;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _cardAnimations = List.generate(5, (index) {
      final start = index * 0.15;
      final end = start + 0.4;
      return CurvedAnimation(
        parent: _animationController,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutBack),
      );
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final authRepo = context.read<IAuthRepository>();
      final currentUser = authRepo.currentUser;
      if (currentUser == null) throw Exception("No user logged in");

      context.read<HealthWizardProvider>().stopHealthCheck();
      final result = context
          .read<HealthWizardProvider>()
          .generateFinalResult(currentUser.id);

      await context.read<IHistoryRepository>().addRecord(result);
      SyncService().triggerSync();

      if (mounted) context.go(AppRoutes.summary);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthWizardProvider>();

    final int heartRate = provider.currentHeartRate;
    final int sys = provider.currentSystolic;
    final int dia = provider.currentDiastolic;
    final int spo2 = provider.currentSpO2;
    final double temp = provider.currentTemp;
    final double bmi = provider.bmi;

    // Evaluations
    final hrEval = VitalValidator.evaluateHR(heartRate);
    final bpEval = VitalValidator.evaluateBP(sys, dia);
    final oxyEval = VitalValidator.evaluateSpO2(spo2);
    final tempEval = VitalValidator.evaluateTemp(temp);
    final bmiEval = VitalValidator.evaluateBMI(bmi);

    final results = [
      _ResultData(Icons.favorite_rounded, "Heart Rate", "$heartRate", "bpm", hrEval),
      _ResultData(Icons.speed_rounded, "Blood Pressure", "$sys/$dia", "mmHg", bpEval),
      _ResultData(Icons.air_rounded, "Oxygen", "$spo2", "%", oxyEval),
      _ResultData(Icons.thermostat_rounded, "Temperature", temp.toStringAsFixed(1), "°C", tempEval),
      _ResultData(Icons.scale_rounded, "BMI Score", bmi.toStringAsFixed(1), "kg/m²", bmiEval),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
        child: Column(
          children: [
            // Dashboard Header
            FadeTransition(
              opacity: _animationController,
              child: Column(
                children: [
                  const Text(
                    "Your Health Dashboard",
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brandDark,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Real-time analysis complete. Review your vitals below.",
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Animated Results Grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                ),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final data = results[index];
                  return AnimatedBuilder(
                    animation: _cardAnimations[index],
                    builder: (context, child) {
                      final animValue = _cardAnimations[index].value.clamp(0.0, 1.0);
                      return Transform.translate(
                        offset: Offset(0, 50 * (1 - animValue)),
                        child: Opacity(
                          opacity: animValue,
                          child: VitalSignDisplay(
                            icon: data.icon,
                            label: data.label,
                            value: data.value,
                            unit: data.unit,
                            evaluation: data.evaluation,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FlowAnimatedButton(
                    child: _buildButtonContainer(Colors.white, "Discard",
                        Colors.red, () => context.go(AppRoutes.home)),
                  ),
                  const SizedBox(width: 32),
                  if (_isSaving)
                    const CircularProgressIndicator(color: AppColors.brandGreen)
                  else
                    FlowAnimatedButton(
                      child: _buildButtonContainer(AppColors.brandGreen,
                          "Save & Finish", Colors.white, _handleSave),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonContainer(
      Color color, String label, Color textColor, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(50),
        border: color == Colors.white
            ? Border.all(color: Colors.grey.withValues(alpha: 0.3))
            : null,
        boxShadow: color != Colors.white
            ? [
                BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(50),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          splashColor: textColor.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
            child: Text(label,
                style: TextStyle(
                    fontSize: 20,
                    color: textColor,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

class _ResultData {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final VitalEvaluation evaluation;

  _ResultData(this.icon, this.label, this.value, this.unit, this.evaluation);
}
