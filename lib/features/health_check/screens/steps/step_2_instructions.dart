import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/flow_animated_button.dart';

class Step2Instructions extends StatelessWidget {
  final VoidCallback onNext;

  const Step2Instructions({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.medical_services_outlined,
              size: 100, color: AppColors.brandGreen),
          const SizedBox(height: 40),
          const Text(
            "Get Ready",
            style: TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.bold,
                color: AppColors.brandDark),
          ),
          const SizedBox(height: 20),
          _buildInstructionItem("1. Stand upright and relax."),
          _buildInstructionItem("2. Place your left arm in the cuff."),
          _buildInstructionItem("3. Do not speak during measurement."),
          const SizedBox(height: 20),
          const Text(
            "Follow the instructions above for accurate measurement.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, color: Colors.black, height: 1.5),
          ),
          const Spacer(),
          FlowAnimatedButton(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.brandGreen,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGreen.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(50),
                child: InkWell(
                  onTap: onNext,
                  borderRadius: BorderRadius.circular(50),
                  splashColor: Colors.white.withValues(alpha: 0.3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 20),
                    child: const Text("Start Measurement",
                        style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 24, color: Colors.grey),
      ),
    );
  }
}
