import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

// CORE
import '../../../../core/constants/app_colors.dart';
import '../../../../core/config/routes.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../../../core/widgets/vital_sign_display.dart';

// LOGIC & DATA
import '../../logic/health_wizard_provider.dart';
import '../../../user_history/data/history_repository.dart';
import '../../../auth/data/auth_repository.dart'; // Needed to get User ID

class Step4Results extends StatefulWidget {
  const Step4Results({super.key});

  @override
  State<Step4Results> createState() => _Step4ResultsState();
}

class _Step4ResultsState extends State<Step4Results> {
  bool _isSaving = false;

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    try {
      // 1. Get Current User ID
      final authRepo = context.read<AuthRepository>();
      final currentUser = authRepo.currentUser;

      if (currentUser == null) {
        throw Exception("No user logged in");
      }

      // 2. Stop Hardware
      context.read<HealthWizardProvider>().stopHealthCheck();

      // 3. Generate Data Packet with User ID
      final result = context
          .read<HealthWizardProvider>()
          .generateFinalResult(currentUser.id);

      // 4. Save to SQLite
      await context.read<HistoryRepository>().addRecord(result);

      // 5. Navigate
      if (mounted) {
        context.go(AppRoutes.summary);
      }
    } catch (e) {
      debugPrint("Save Error: $e");
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

    // ... (Rest of UI build method remains same as previous version)
    // Just copying the essential parts to keep response concise,
    // but the key logic change is in _handleSave above.

    final int heartRate = provider.currentHeartRate;
    final String bp =
        "${provider.currentSystolic}/${provider.currentDiastolic}";
    final String spo2 = "${provider.currentSpO2}";
    final String temp = provider.currentTemp.toStringAsFixed(1);
    final String bmi = provider.bmi.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Text(
            "Your Results",
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.brandDark),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              children: [
                _buildResultCard(
                    child: VitalSignDisplay(
                        icon: Icons.favorite,
                        iconColor: Colors.red,
                        label: "Heart Rate",
                        value: "$heartRate",
                        unit: "bpm")),
                _buildResultCard(
                    child: VitalSignDisplay(
                        icon: Icons.speed,
                        iconColor: Colors.blue,
                        label: "Blood Pressure",
                        value: bp,
                        unit: "mmHg")),
                _buildResultCard(
                    child: VitalSignDisplay(
                        icon: Icons.air,
                        iconColor: Colors.cyan,
                        label: "Oxygen",
                        value: spo2,
                        unit: "%")),
                _buildResultCard(
                    child: VitalSignDisplay(
                        icon: Icons.thermostat,
                        iconColor: Colors.orange,
                        label: "Temperature",
                        value: temp,
                        unit: "°C")),
                _buildResultCard(
                    child: VitalSignDisplay(
                        icon: Icons.scale,
                        iconColor: Colors.purple,
                        label: "BMI Score",
                        value: bmi,
                        unit: provider.bmiCategory)),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FlowAnimatedButton(
                child: _buildButtonContainer(Colors.white, "Discard",
                    Colors.red, () => context.go(AppRoutes.home)),
              ),
              const SizedBox(width: 24),
              if (_isSaving)
                const CircularProgressIndicator(color: AppColors.brandGreen)
              else
                FlowAnimatedButton(
                  child: _buildButtonContainer(AppColors.brandGreen,
                      "Save & Finish", Colors.white, _handleSave),
                ),
            ],
          ),
        ],
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

  Widget _buildResultCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Center(child: child),
    );
  }
}
