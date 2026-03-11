import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/kiosk_scaffold.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../../../core/widgets/virtual_keyboard.dart';
import '../../logic/health_wizard_provider.dart';

// DATA & REPO
import '../../../user_history/data/history_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../models/vital_signs_model.dart';

class BmiTestScreen extends StatefulWidget {
  const BmiTestScreen({super.key});

  @override
  State<BmiTestScreen> createState() => _BmiTestScreenState();
}

class _BmiTestScreenState extends State<BmiTestScreen> {
  // 0 = Input Height, 1 = Measure Weight & Result
  int _stage = 0;
  final TextEditingController _heightController =
      TextEditingController(text: "165");
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    // Ensure sensor starts for weight reading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HealthWizardProvider>().startHealthCheck();
    });
  }

  // SAVE LOGIC
  Future<void> _saveAndFinish() async {
    final provider = context.read<HealthWizardProvider>();
    final historyRepo = context.read<HistoryRepository>();
    final authRepo = context.read<AuthRepository>();

    // 1. Check if user is logged in
    if (authRepo.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Error: No user logged in. Data cannot be saved."),
          backgroundColor: Colors.red));
      context.pop();
      return;
    }

    // 2. Create Record with BMI Data
    final VitalSigns record = VitalSigns(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: authRepo.currentUser!.id,
      timestamp: DateTime.now(),
      // Default other vitals to 0/empty as this is a specific test
      heartRate: 0,
      systolicBP: 0,
      diastolicBP: 0,
      oxygen: 0,
      temperature: 0.0,
      // Save BMI specific data
      bmi: provider.bmi,
      bmiCategory: provider.bmiCategory,
    );

    // 3. Save to Database
    await historyRepo.addRecord(record);
    provider.stopHealthCheck();

    // 4. Feedback & Exit
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("BMI Result saved to History"),
        backgroundColor: AppColors.brandGreen,
        duration: Duration(seconds: 2),
      ));
      context.pop();
    }
  }

  void _showKeyboard() {
    setState(() => _isKeyboardVisible = true);
    showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: VirtualKeyboard(
          controller: _heightController,
          type: KeyboardType.numeric,
          maxLength: 3,
          onSubmit: () => Navigator.pop(ctx),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _isKeyboardVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthWizardProvider>();

    return KioskScaffold(
      title: "BMI & Weight Check",
      onBackTap: () {
        context.read<HealthWizardProvider>().stopHealthCheck();
        context.pop();
      },
      body: Center(
        child: _stage == 0
            ? _buildHeightInput(context)
            : _buildResultView(context, provider),
      ),
    );
  }

  Widget _buildHeightInput(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.height, size: 80, color: AppColors.brandGreen),
          const SizedBox(height: 24),
          const Text("Enter Your Height",
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandDark)),
          const SizedBox(height: 16),
          const Text("We need this to calculate your BMI accurately.",
              style: TextStyle(fontSize: 18, color: Colors.grey)),

          const SizedBox(height: 40),

          // INPUT FIELD
          GestureDetector(
            onTap: _showKeyboard,
            child: Container(
              width: 300,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _isKeyboardVisible
                          ? AppColors.brandGreen
                          : Colors.grey.shade300,
                      width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 8))
                  ]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_heightController.text,
                      style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandDark)),
                  const SizedBox(width: 8),
                  const Text("cm",
                      style: TextStyle(
                          fontSize: 24,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 60),

          FlowAnimatedButton(
            child: ElevatedButton(
              onPressed: () {
                int? height = int.tryParse(_heightController.text);
                if (height != null && height > 50 && height < 250) {
                  context.read<HealthWizardProvider>().setHeight(height);
                  setState(() => _stage = 1);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text("Please enter a valid height (50-250 cm)")));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 60, vertical: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
                elevation: 5,
              ),
              child: const Text("Next: Weigh In",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ),

          // Padding for keyboard
          SizedBox(height: _isKeyboardVisible ? 350 : 0),
        ],
      ),
    );
  }

  Widget _buildResultView(BuildContext context, HealthWizardProvider provider) {
    Color bmiColor = AppColors.brandGreen;
    if (provider.bmi < 18.5) bmiColor = Colors.blue;
    if (provider.bmi > 25) bmiColor = Colors.orange;
    if (provider.bmi > 30) bmiColor = Colors.red;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Measurement Complete",
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandDark)),
          const SizedBox(height: 40),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Weight Box
              _buildResultCard(
                  "WEIGHT",
                  "${provider.weightKg.toStringAsFixed(1)} kg",
                  Colors.grey,
                  Colors.white),
              const SizedBox(width: 32),
              // BMI Box
              _buildResultCard("BMI SCORE", provider.bmi.toStringAsFixed(1),
                  bmiColor, bmiColor.withValues(alpha: 0.1)),
            ],
          ),

          const SizedBox(height: 40),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
                color: bmiColor,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                      color: bmiColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]),
            child: Text(
              provider.bmiCategory.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),
          ),

          const SizedBox(height: 60),

          // UPDATED: Save & Finish Button
          FlowAnimatedButton(
            child: ElevatedButton(
              onPressed: _saveAndFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandDark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
              ),
              child: const Text("Save & Finish",
                  style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(
      String title, String value, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandDark)),
        ],
      ),
    );
  }
}
