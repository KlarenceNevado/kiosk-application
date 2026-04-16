import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../../../core/widgets/virtual_keyboard.dart';
import '../../../../core/services/hardware/sensor_service_interface.dart';
import '../../logic/health_wizard_provider.dart';

class StepHeightInput extends StatefulWidget {
  final VoidCallback onNext;
  const StepHeightInput({super.key, required this.onNext});

  @override
  State<StepHeightInput> createState() => _StepHeightInputState();
}

class _StepHeightInputState extends State<StepHeightInput> {
  // Use a controller to bridge VirtualKeyboard and Display
  final TextEditingController _heightController =
      TextEditingController(text: "165");

  @override
  void initState() {
    super.initState();
    // Start automated height scan if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HealthWizardProvider>().startSensor(SensorType.height);
    });
  }

  @override
  void dispose() {
    // We don't stop it here because the user might still be on the screen, 
    // but the next step will stop it via captureVital.
    _heightController.dispose();
    super.dispose();
  }

  void _confirmHeight() {
    int? height = int.tryParse(_heightController.text);
    if (height != null && height >= 50 && height <= 250) {
      context.read<HealthWizardProvider>().setHeight(height);
      widget.onNext();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please enter a valid height (50 - 250 cm).")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthWizardProvider>();
    
    // AUTO-FILL: If sensor provides a stable reading, update the manual field
    if (provider.getSensorStatus(SensorType.height) == SensorStatus.reading &&
        provider.heightCm > 50 &&
        provider.heightCm != int.tryParse(_heightController.text)) {
      Future.delayed(Duration.zero, () {
        if (mounted) {
           _heightController.text = provider.heightCm.toString();
        }
      });
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // LEFT: Info & Display
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.height_rounded,
                      size: 80, color: AppColors.brandGreen),
                  const SizedBox(height: 24),
                  const Text("Your Height",
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandDark)),
                  const SizedBox(height: 8),
                  const Text("Enter your height in centimeters.",
                      style: TextStyle(fontSize: 18, color: Colors.grey)),

                  const SizedBox(height: 40),

                  // Display Box
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 24),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: AppColors.brandGreen, width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 8))
                        ]),
                    child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _heightController,
                        builder: (context, value, child) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(value.text.isEmpty ? "-" : value.text,
                                  style: const TextStyle(
                                      fontSize: 64,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.brandDark)),
                              const SizedBox(width: 12),
                              const Text("cm",
                                  style: TextStyle(
                                      fontSize: 24,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w600)),
                            ],
                          );
                        }),
                  ),

                  const SizedBox(height: 40),

                  // Next Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: FlowAnimatedButton(
                      child: ElevatedButton(
                        onPressed: _confirmHeight,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandGreen,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Next: Measure Weight",
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 40),

            // RIGHT: Integrated Numpad (Always Visible)
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(32),
                ),
                child: VirtualKeyboard(
                  controller: _heightController,
                  type: KeyboardType.numeric,
                  maxLength: 3,
                  // On 'Done', trigger next
                  onSubmit: _confirmHeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
