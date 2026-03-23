import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/flow_animated_button.dart';

class Step1Consent extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onCancel;

  const Step1Consent({
    super.key,
    required this.onNext,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. SECURITY ICON
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security_rounded,
                  size: 80, color: AppColors.brandGreen),
            ),
  
            const SizedBox(height: 32),
  
            // 2. HEADLINE
            const Text(
              "Data Privacy Consent",
              style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandDark),
              textAlign: TextAlign.center,
            ),
  
            const SizedBox(height: 24),
  
            // 3. DETAILED EXPLANATION (Bullet Points for readability)
            Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 700),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBulletPoint(
                      "We collect your vital signs (BP, Heart Rate, etc.) for screening purposes."),
                  const SizedBox(height: 12),
                  _buildBulletPoint(
                      "Your data is stored LOCALLY on this kiosk and is not uploaded to the public internet."),
                  const SizedBox(height: 12),
                  _buildBulletPoint(
                      "Only authorized Barangay Health Workers can access your history."),
                  const SizedBox(height: 12),
                  _buildBulletPoint(
                      "By proceeding, you agree to the processing of your personal health information."),
                ],
              ),
            ),
  
            const SizedBox(height: 32),
  
            // 4. ACTION BUTTONS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // CANCEL BUTTON (Fixed Tap Area)
                FlowAnimatedButton(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.5), width: 2),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(50),
                      child: InkWell(
                        onTap: onCancel,
                        borderRadius: BorderRadius.circular(50),
                        splashColor: Colors.red.withValues(alpha: 0.1),
                        // PADDING INSIDE INKWELL = BIGGER HIT TARGET
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                          child: Text("Decline",
                              style: TextStyle(
                                  fontSize: 22,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ),
  
                const SizedBox(width: 32),
  
                // AGREE BUTTON
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
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: Colors.white, size: 28),
                              SizedBox(width: 12),
                              Text("I Agree, Start",
                                  style: TextStyle(
                                      fontSize: 22,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6.0),
          child: Icon(Icons.check, size: 20, color: AppColors.brandGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 18, color: Colors.black87, height: 1.4),
          ),
        ),
      ],
    );
  }
}
