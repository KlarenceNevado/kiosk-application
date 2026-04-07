import 'dart:async';
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
  // 0=Height, 1=Wait, 2=Measuring, 3=Result, 4=Error
  int _stage = 0;
  final TextEditingController _heightController = TextEditingController(text: "165");
  
  String _lockedWeight = ""; 
  Timer? _simTimer;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HealthWizardProvider>().startHealthCheck();
    });
  }

  void _startWeightMeasurement() {
    setState(() => _stage = 2);
    final provider = context.read<HealthWizardProvider>();
    provider.startSensor(SensorType.weight);

    // HARDENING: Safety Timeout
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _stage == 2) {
        setState(() => _stage = 4);
      }
    });

    if (!AppEnvironment().useSimulation) return;

    int ticks = 0;
    _simTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) { timer.cancel(); return; }
      ticks++;
      provider.setWeight(50.0 + (ticks * 0.5));
      if (ticks >= 20) {
        timer.cancel();
      }
    });
  }

  void _lockValueAndFinish() {
    if (!mounted || _stage == 3) return;
    _timeoutTimer?.cancel();
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
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthWizardProvider>();
    const Color themeColor = AppColors.brandGreen; 

    // HARDENING: Auto-lock
    if (_stage == 2 && provider.isVitalStable(SensorType.weight) && provider.weightKg > 5) {
       Future.delayed(Duration.zero, _lockValueAndFinish);
    }

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
            : _stage == 1 ? _buildReadyWait(themeColor) 
            : _stage == 4 ? _buildErrorView(themeColor) : _buildMeasurementView(provider, themeColor),
        ),
      ),
    );
  }

  Widget _buildHeightInput(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Row(
        children: [
          Expanded(
            flex: 45,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.height_rounded, size: 60, color: color),
                const SizedBox(height: 16),
                const Text("Your Height", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.brandDark, letterSpacing: -1)),
                const Text("Enter your height in centimeters.", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 32),

                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _heightController,
                  builder: (context, value, _) {
                    return Container(
                      width: 280, padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.4), width: 3),
                        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 15)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(value.text, style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: AppColors.brandDark, letterSpacing: -2)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      elevation: 6,
                    ),
                    child: const Text("Next: Measure Weight", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          
          const VerticalDivider(width: 1, color: Color(0xFFF0F0F0)),
          
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
                     padding: const EdgeInsets.all(12.0),
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
          child: Icon(Icons.scale_rounded, size: 72, color: color),
        ),
        const SizedBox(height: 24),
        const Text("Precautionary Stage", style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
        const SizedBox(height: 12),
        const Text("Stand consistently on the platform scale.", style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.w500)),
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
            child: const Text("Start Measurement", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementView(HealthWizardProvider provider, Color color) {
    final isDone = _stage == 3;
    final displayWeight = isDone ? _lockedWeight : (provider.weightKg > 0 ? provider.weightKg.toStringAsFixed(1) : "0.0");

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
                  width: 280 * val, height: 280 * val,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.1), width: 3)),
                ),
              ),
            
            SizedBox(
              width: 300, height: 300,
              child: CircularProgressIndicator(
                value: isDone ? 1 : null, strokeWidth: 12, strokeCap: StrokeCap.round,
                color: isDone ? color : color.withValues(alpha: 0.1),
                backgroundColor: color.withValues(alpha: 0.05),
              ),
            ),

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(displayWeight, style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: isDone ? color : color, letterSpacing: -2)),
                const Text("kg", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 48),
        
        if (!isDone)
           Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(50)),
            child: Text("STABILIZING...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          )
        else
          _buildBmiBadge(provider, color),

        const SizedBox(height: 48),
        
        if (isDone)
          FlowAnimatedButton(
            child: ElevatedButton(
              onPressed: _saveAndFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                elevation: 4,
              ),
              child: const Text("Save & Record BMI", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView(Color color) {
    return Column(
      key: const ValueKey(4),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 80),
        const SizedBox(height: 24),
        const Text("Scale Error", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
        const SizedBox(height: 12),
        const Text("Could not get a stable reading. Please try again.", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey)),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => setState(() => _stage = 1),
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
          child: const Text("Retry Scale", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
          child: Text("${provider.bmiCategory.toUpperCase()}  (BMI: ${provider.bmi.toStringAsFixed(1)})", style: TextStyle(color: bmiColor, fontSize: 20, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}
