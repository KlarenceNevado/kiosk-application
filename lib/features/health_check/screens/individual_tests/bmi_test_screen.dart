import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/kiosk_scaffold.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../../../core/widgets/virtual_keyboard.dart';
import '../../logic/health_wizard_provider.dart';
import '../../../../core/services/hardware/sensor_service_interface.dart';
import '../../../../core/services/system/app_environment.dart';

// DATA & REPO
import '../../../user_history/domain/i_history_repository.dart';
import '../../../auth/domain/i_auth_repository.dart';
import '../../models/vital_signs_model.dart';

class BmiTestScreen extends StatefulWidget {
  const BmiTestScreen({super.key});

  @override
  State<BmiTestScreen> createState() => _BmiTestScreenState();
}

class _BmiTestScreenState extends State<BmiTestScreen> {
  // 0 = Input Height, 1 = Ready Wait, 2 = Measuring, 3 = Result
  int _stage = 0;
  final TextEditingController _heightController = TextEditingController(text: "165");
  
  String _simWeightDisplay = "--.-";
  String _lockedWeight = ""; 
  Timer? _simTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HealthWizardProvider>().startHealthCheck();
    });
  }

  void _startWeightMeasurement() {
    setState(() => _stage = 2);
    context.read<HealthWizardProvider>().startSensor(SensorType.weight);

    if (!AppEnvironment().useSimulation) return;

    double currentSimWeight = 40.0;
    double targetWeight = 65.0 + (Random().nextDouble() * 10);
    int ticks = 0;
    _simTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) { timer.cancel(); return; }
      ticks++;
      setState(() {
        double progress = ticks / 30;
        currentSimWeight = 40.0 + (targetWeight - 40.0) * progress;
        _simWeightDisplay = currentSimWeight.toStringAsFixed(1);
      });

      if (ticks >= 30) {
        timer.cancel();
        context.read<HealthWizardProvider>().setWeight(double.parse(targetWeight.toStringAsFixed(1)));
        _lockValueAndFinish();
      }
    });
  }

  void _lockValueAndFinish() {
    final provider = context.read<HealthWizardProvider>();
    setState(() {
       _stage = 3;
       _lockedWeight = provider.weightKg.toStringAsFixed(1);
    });
  }

  Future<void> _saveAndFinish() async {
    final provider = context.read<HealthWizardProvider>();
    final historyRepo = context.read<IHistoryRepository>();
    final authRepo = context.read<IAuthRepository>();

    if (authRepo.currentUser == null) return;

    final VitalSigns record = VitalSigns(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: authRepo.currentUser!.id,
      timestamp: DateTime.now(),
      heartRate: 0, systolicBP: 0, diastolicBP: 0, oxygen: 0, temperature: 0.0,
      bmi: provider.bmi, bmiCategory: provider.bmiCategory,
    );

    await historyRepo.addRecord(record);
    provider.stopHealthCheck();
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthWizardProvider>();
    const Color themeColor = AppColors.brandGreen; 

    return KioskScaffold(
      title: "BMI & Weight",
      onBackTap: () {
        context.read<HealthWizardProvider>().stopHealthCheck();
        context.pop();
      },
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.white, themeColor.withValues(alpha: 0.02)],
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _stage == 0 
            ? _buildHeightInput(themeColor) 
            : _stage == 1 ? _buildReadyWait(themeColor) : _buildMeasurementView(provider, themeColor),
        ),
      ),
    );
  }

  Widget _buildHeightInput(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Row(
        children: [
          // LEFT: Input Content
          Expanded(
            flex: 45,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.height_rounded, size: 60, color: color), // Enlarged from 48
                const SizedBox(height: 16),
                const Text("Your Height", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.brandDark, letterSpacing: -1)), // Enlarged from 28
                const Text("Enter your height in centimeters.", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500)), // Enlarged from 15
                const SizedBox(height: 32),

                // THE BUG FIX: LIVE PREVIEW OF TYPING
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _heightController,
                  builder: (context, value, _) {
                    return Container(
                      width: 280, padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20), // Enlarged
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.4), width: 3), // Thicker border
                        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 15)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(value.text, style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: AppColors.brandDark, letterSpacing: -2)), // Enlarged from 48
                          const SizedBox(width: 10),
                          const Text("cm", style: TextStyle(fontSize: 24, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }
                ),

                const SizedBox(height: 48),

                FlowAnimatedButton(
                  child: ElevatedButton(
                    onPressed: () {
                      int? h = int.tryParse(_heightController.text);
                      if (h != null && h > 50 && h < 250) {
                         context.read<HealthWizardProvider>().setHeight(h);
                         setState(() => _stage = 1);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20), // Larger padding
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      elevation: 6,
                    ),
                    child: const Text("Next: Measure Weight", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), // Enlarged from 18
                  ),
                ),
              ],
            ),
          ),
          
          const VerticalDivider(width: 1, color: Color(0xFFF0F0F0)),
          
          // RIGHT: Integrated Keypad
          Expanded(
            flex: 55,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(20),
                child: Material(
                   elevation: 10,
                   borderRadius: BorderRadius.circular(24),
                   color: Colors.white,
                   child: Padding(
                     padding: const EdgeInsets.all(12.0), // More room
                     child: VirtualKeyboard(
                        controller: _heightController,
                        type: KeyboardType.numeric,
                        maxLength: 3,
                     ),
                   ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyWait(Color color) {
    return Column(
      key: const ValueKey(1),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 20)]),
          child: Icon(Icons.scale_rounded, size: 72, color: color), // Enlarged from 64
        ),
        const SizedBox(height: 24),
        const Text("Precautionary Stage", style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: AppColors.brandDark)), // Enlarged from 24
        const SizedBox(height: 12),
        const Text("Stand consistently on the platform scale.", style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.w500)), // Enlarged from 16
        const SizedBox(height: 48),
        FlowAnimatedButton(
          child: ElevatedButton(
            onPressed: _startWeightMeasurement,
            style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              elevation: 4,
            ),
            child: const Text("Start Measurement", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), // Enlarged from 18
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementView(HealthWizardProvider provider, Color color) {
    final isDone = _stage == 3;
    final displayWeight = isDone ? _lockedWeight : (AppEnvironment().useSimulation ? _simWeightDisplay : (provider.weightKg > 0 ? provider.weightKg.toStringAsFixed(1) : "0.0"));

    return Column(
      key: const ValueKey(2),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (!isDone)
              TweenAnimationBuilder(
                duration: const Duration(seconds: 1), tween: Tween<double>(begin: 1.0, end: 1.2),
                builder: (context, val, child) => Container(
                  width: 280 * val, height: 280 * val, // Enlarged
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.1), width: 3)),
                ),
              ),
            
            SizedBox(
              width: 300, height: 300, // Enlarged from 260
              child: CircularProgressIndicator(
                value: isDone ? 1 : null, strokeWidth: 12, strokeCap: StrokeCap.round, // Thicker
                color: isDone ? color : color.withValues(alpha: 0.1),
                backgroundColor: color.withValues(alpha: 0.05),
              ),
            ),

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(displayWeight, style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: isDone ? color : color, letterSpacing: -2)), // Enlarged from 60
                const Text("kg", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)), // Enlarged
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 48),
        
        if (!isDone)
           Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(50)),
            child: Text("STABILIZING...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)), // Enlarged from 14
          )
        else
          _buildBmiBadge(provider, color),

        const SizedBox(height: 48),
        
        if (isDone || (!AppEnvironment().useSimulation && _stage == 2))
          FlowAnimatedButton(
            child: ElevatedButton(
              onPressed: _saveAndFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                elevation: 4,
              ),
              child: const Text("Save & Record BMI", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), // Enlarged from 18
            ),
          ),
      ],
    );
  }

  Widget _buildBmiBadge(HealthWizardProvider provider, Color color) {
    Color bmiColor = color;
    if (provider.bmi < 18.5) bmiColor = Colors.blue;
    if (provider.bmi > 25) bmiColor = Colors.orange;
    if (provider.bmi > 30) bmiColor = Colors.red;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(color: bmiColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(50), border: Border.all(color: bmiColor, width: 3)),
          child: Text("${provider.bmiCategory.toUpperCase()}  (BMI: ${provider.bmi.toStringAsFixed(1)})", style: TextStyle(color: bmiColor, fontSize: 20, fontWeight: FontWeight.w900)), // Enlarged from 16
        ),
      ],
    );
  }
}
