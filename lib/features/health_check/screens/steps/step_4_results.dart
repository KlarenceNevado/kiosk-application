import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

// CORE
import '../../../../core/constants/app_colors.dart';
import '../../../../core/config/routes.dart';
import '../../../../core/widgets/flow_animated_button.dart';
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
            .showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthWizardProvider>();
    
    // KEEP SESSION ALIVE WHILE READING RESULTS
    context.read<IAuthRepository>().resetSessionTimer();

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
      _ResultData(Icons.favorite_rounded, "Heart Rate", "$heartRate", "bpm", hrEval, Colors.red),
      _ResultData(Icons.speed_rounded, "Blood Pressure", "$sys/$dia", "mmHg", bpEval, Colors.blue),
      _ResultData(Icons.water_drop_rounded, "Oxygen Levels", "$spo2", "%", oxyEval, Colors.cyan),
      _ResultData(Icons.thermostat_rounded, "Body Temperature", temp.toStringAsFixed(1), "°C", tempEval, Colors.orange),
      _ResultData(Icons.scale_rounded, "Body Mass Index", bmi.toStringAsFixed(1), "kg/m²", bmiEval, Colors.purple),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[50]!,
            Colors.white,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: Column(
          children: [
            // Dashboard Header
            FadeTransition(
              opacity: _animationController,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Text(
                      "CHECKUP COMPLETE",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brandGreen,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Clinical Summary",
                    style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brandDark,
                        letterSpacing: -1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Vitals successfully captured and validated.",
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Animated Results List (Medical Report Style)
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: results.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final data = results[index];
                    return AnimatedBuilder(
                      animation: _cardAnimations[index],
                      builder: (context, child) {
                        final animValue = _cardAnimations[index].value.clamp(0.0, 1.0);
                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - animValue)),
                          child: Opacity(
                            opacity: animValue,
                            child: _buildMedicalReportCard(data),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   _buildActionButton(
                    label: "Discard Checkup", 
                    icon: Icons.delete_outline_rounded,
                    color: Colors.red,
                    isOutline: true,
                    onTap: () => context.go(AppRoutes.home),
                  ),
                  const SizedBox(width: 24),
                  if (_isSaving)
                    const CircularProgressIndicator(color: AppColors.brandGreen)
                  else
                    _buildActionButton(
                      label: "Finalize & Save Report", 
                      icon: Icons.check_circle_rounded,
                      color: AppColors.brandGreen,
                      onTap: _handleSave,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalReportCard(_ResultData data) {
    final statusColor = data.evaluation.status == HealthStatus.normal ? AppColors.brandGreen : Colors.orange;
    final statusText = data.evaluation.status == HealthStatus.normal ? "NORMAL" : "ATTENTION";

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: data.themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(data.icon, color: data.themeColor, size: 32),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey[400],
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      data.value,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brandDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      data.unit,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label, 
    required IconData icon, 
    required Color color, 
    required VoidCallback onTap,
    bool isOutline = false,
  }) {
    return FlowAnimatedButton(
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 24),
        label: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutline ? Colors.white : color,
          foregroundColor: isOutline ? color : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          elevation: isOutline ? 0 : 8,
          shadowColor: color.withValues(alpha: 0.4),
          side: isOutline ? BorderSide(color: color.withValues(alpha: 0.3), width: 2) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
  final Color themeColor;

  _ResultData(this.icon, this.label, this.value, this.unit, this.evaluation, this.themeColor);
}
