import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/routes.dart';

class HelpInfoScreen extends StatelessWidget {
  const HelpInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Help & User Guide",
          style: TextStyle(
              color: AppColors.brandDark, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.brandDark),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // --- 1. HERO HEADER ---
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [AppColors.brandGreen, AppColors.brandGreenDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandGreen.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.help_outline_rounded,
                      size: 48, color: Colors.white),
                ),
                const SizedBox(width: 24),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Kiosk User Guide",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Follow the steps below to ensure your vital sign measurements are accurate.",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 40),

          // --- 2. STEP-BY-STEP INSTRUCTIONS (Revised Order) ---
          const Text("Step-by-Step Instructions",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandDark)),
          const SizedBox(height: 16),
          const Text("The check-up follows this specific order:",
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 24),

          LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth > 600;
              final double cardWidth = isWide
                  ? (constraints.maxWidth - 24) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  SensorGuideCard(
                    width: cardWidth,
                    icon: Icons.scale,
                    title: "1. Height & Weight",
                    description:
                        "Remove heavy shoes/bags. Stand still on the platform. Enter your height manually.",
                    step: "Start",
                  ),
                  SensorGuideCard(
                    width: cardWidth,
                    icon: Icons.thermostat,
                    title: "2. Body Temperature",
                    description:
                        "Remove hats or hair from forehead. Position forehead 5cm from the sensor.",
                    step: "Second",
                  ),
                  SensorGuideCard(
                    width: cardWidth,
                    icon: Icons.monitor_heart,
                    title: "3. Pulse & Oxygen",
                    description:
                        "Insert index finger into the clip. Remove nail polish. Keep hand steady.",
                    step: "Third",
                  ),
                  SensorGuideCard(
                    width: cardWidth,
                    icon: Icons.bloodtype,
                    title: "4. Blood Pressure",
                    description:
                        "Wear cuff on LEFT wrist at heart level. Rest elbow on table. Do not talk.",
                    step: "Final",
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 40),

          // --- 3. TROUBLESHOOTING GUIDE ---
          const Text("Troubleshooting & System Status",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandDark)),
          const SizedBox(height: 24),

          const FaqTile(
            question: "The sensor isn't starting or reading.",
            answer:
                "Ensure the device (BP Cuff or finger clip) is properly connected and there are no loose cables. For Temperature, stay 5cm away. For BP, keep the cuff at heart level and do not talk.",
          ),
          const FaqTile(
            question: "My login failing with 'Security Lock'.",
            answer:
                "For your protection, the system locks accounts for 5 minutes after 5 failed PIN attempts. Please wait for the lockout to expire before trying again.",
          ),
          const FaqTile(
            question: "What does the 'Sync' icon mean?",
            answer:
                "🟢 Green: All data is safely backed up to the cloud.\n🟡 Yellow: Data is saved locally but waiting for internet to sync.\n🔴 Red: There is a connection issue; alert a health worker.",
          ),
          const FaqTile(
            question: "The touch screen is not responsive.",
            answer:
                "Ensure your hands are dry. If the system hangs, please ask the Barangay Health Worker (BHW) to restart the terminal.",
          ),

          const SizedBox(height: 40),

          // --- 4. GENERAL FAQs ---
          const Text("Security & Privacy FAQ",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandDark)),
          const SizedBox(height: 24),

          const FaqTile(
            question: "Is my personal data safe?",
            answer:
                "Yes. We use 'Zero-Knowledge' encryption. Your PIN is stored as a non-reversible SHA-256 hash. Even we cannot see your raw PIN. All data is handled according to the Philippine Data Privacy Act (DPA 2012).",
          ),
          const FaqTile(
            question: "I forgot my PIN. What should I do?",
            answer:
                "Because of our security model, we cannot 'recover' your PIN. Please see the authorized Barangay Health Worker (BHW) to verify your identity and help you reset your account access.",
          ),
          const FaqTile(
            question: "Where can I see my historical results?",
            answer:
                "Your results are instantly synced to your Patient Portal. Scan the QR code at the end of your session or visit the Isla Verde Health Web App to see your full history.",
          ),
          const FaqTile(
            question: "Can I register my family members?",
            answer:
                "Yes! You can register as a Head of Household and add dependents. Their data will be linked to your account for easy health monitoring.",
          ),

          const SizedBox(height: 60),

          // --- 5. ADMIN ACCESS (Hidden) ---
          Center(
            child: GestureDetector(
              onLongPress: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Accessing Technician Mode..."),
                  duration: Duration(seconds: 1),
                ));
                context.push(AppRoutes.adminLogin);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.transparent,
                child: Column(
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        color: AppColors.brandGreen, size: 24),
                    const SizedBox(height: 8),
                    Text(
                      "System Version 3.1.0 • Secure Build",
                      style: TextStyle(
                          color: Colors.grey[400], fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "(Zero-Knowledge Virtual Vault Active)",
                      style: TextStyle(color: Colors.grey[300], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// --- WIDGETS ---

class SensorGuideCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String description;
  final String step;

  const SensorGuideCard({
    super.key,
    required this.width,
    required this.icon,
    required this.title,
    required this.description,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B7A99).withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brandGreenLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.brandGreen, size: 28),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  step.toUpperCase(),
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.brandDark),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style:
                TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
          ),
        ],
      ),
    );
  }
}

class FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const FaqTile({
    super.key,
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ]),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            question,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.brandDark,
                fontSize: 16),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          expandedAlignment: Alignment.centerLeft,
          iconColor: AppColors.brandGreen,
          children: [
            Text(
              answer,
              style:
                  TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
