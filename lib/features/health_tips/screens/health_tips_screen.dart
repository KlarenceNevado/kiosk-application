import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/routes.dart';
import '../../../core/widgets/kiosk_scaffold.dart';
import '../../../core/widgets/flow_animated_button.dart';
// FIXED: Removed unused import 'package:intl/intl.dart'

class HealthTipsScreen extends StatefulWidget {
  const HealthTipsScreen({super.key});

  @override
  State<HealthTipsScreen> createState() => _HealthTipsScreenState();
}

class _HealthTipsScreenState extends State<HealthTipsScreen> {
  // --- ISLA VERDE WEATHER ENGINE ---
  Map<String, dynamic> _getRealTimeAlert() {
    final now = DateTime.now();
    final month = now.month;
    final hour = now.hour;

    // 1. TAG-INIT (Summer): March, April, May
    if (month >= 3 && month <= 5) {
      // Real-time check: Is it peak sun hours? (10 AM - 3 PM)
      if (hour >= 10 && hour <= 15) {
        return {
          "icon": Icons.wb_sunny_rounded,
          "color": Colors.orange,
          "title": "EXTREME HEAT ALERT (Tag-init)",
          "desc":
              "It is currently peak sun hour in Isla Verde. Stay indoors, drink water every 15 mins, and avoid physical labor."
        };
      }
      return {
        "icon": Icons.water_drop_rounded,
        "color": Colors.orange,
        "title": "Heat Stroke Prevention",
        "desc":
            "Temperatures are high today. Wear light clothing and watch for signs of dizziness. Keep hydrated."
      };
    }

    // 2. TAG-ULAN (Rainy/Habagat): June to November
    if (month >= 6 && month <= 11) {
      // Real-time check: Mosquitoes are active at dawn/dusk (5-7 PM)
      if (hour >= 17 && hour <= 19) {
        return {
          "icon": Icons.pest_control,
          "color": Colors.purple,
          "title": "DENGUE ALERT: Active Hours",
          "desc":
              "Mosquitoes are active right now. Wear long sleeves or apply repellent if going outside."
        };
      }
      return {
        "icon": Icons.umbrella_rounded,
        "color": Colors.blueGrey,
        "title": "Rainy Season Safety",
        "desc":
            "Risk of Dengue and Leptospirosis is high. Remove stagnant water around your home. Do not wade in floodwater."
      };
    }

    // 3. AMIHAN (Cool Dry): December, January, February
    // Default fallback for "Cool" season
    return {
      "icon": Icons.ac_unit_rounded, // Cool air icon
      "color": Colors.teal,
      "title": "Cold & Flu Season (Amihan)",
      "desc":
          "Cooler winds from Batangas Bay can lower immunity. Take Vitamin C, wear a jacket at night, and cover your cough."
    };
  }

  @override
  Widget build(BuildContext context) {
    // Calculate the alert based on the exact moment the user opens the page
    final alertData = _getRealTimeAlert();

    return KioskScaffold(
      title: "Health Education & Guides",
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: ListView(
            padding: const EdgeInsets.all(32),
            children: [
              // --- 1. HERO SECTION: EMERGENCY ---
              _buildHeroTip(context),

              const SizedBox(height: 32),

              // --- 2. DYNAMIC SEASONAL ALERT (Batangas Real-Time) ---
              _buildSeasonalAlert(context, alertData['icon'],
                  alertData['color'], alertData['title'], alertData['desc']),

              const SizedBox(height: 40),

              // --- 3. QUICK SYMPTOM GUIDE ---
              const Text("Feeling Unwell? Quick Reference:",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark)),
              const SizedBox(height: 16),
              _buildSymptomRow(),

              const SizedBox(height: 40),

              // --- 4. DETAILED METRICS GRID ---
              const Text("Understanding Your Vitals",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark)),
              const SizedBox(height: 8),
              const Text(
                  "Tap any card to learn normal ranges, how to measure, and what to do next.",
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 24),

              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 1;
                  double childAspectRatio = 2.2;

                  if (constraints.maxWidth > 1600) {
                    crossAxisCount = 4;
                    childAspectRatio = 1.3;
                  } else if (constraints.maxWidth > 1100) {
                    crossAxisCount = 3;
                    childAspectRatio = 1.4;
                  } else if (constraints.maxWidth > 600) {
                    crossAxisCount = 2;
                    childAspectRatio = 1.6;
                  }

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                    childAspectRatio: childAspectRatio,
                    children: [
                      _buildTipCard(
                        context,
                        icon: Icons.speed_rounded,
                        color: Colors.blue,
                        title: "Blood Pressure",
                        subtitle: "Heart Health Monitor",
                        instruction:
                            "Sit comfortably with your back supported. Place the cuff on your LEFT wrist at heart level. Relax your arm on a table.",
                        content:
                            "• Normal: < 120/80 mmHg\n• Elevated: 120-129 / <80\n• High Stage 1: 130-139 / 80-89\n• High Stage 2: 140+ / 90+\n\nWHY IT MATTERS:\nHigh BP (Hypertension) has no obvious symptoms but damages arteries, heart, and kidneys.",
                        canMeasure: true,
                      ),
                      _buildTipCard(
                        context,
                        icon: Icons.air_rounded,
                        color: Colors.cyan,
                        title: "Oxygen (SpO₂)",
                        subtitle: "Lung Function",
                        instruction:
                            "Insert your index finger into the clip sensor. Keep your hand steady and relaxed. Remove nail polish if possible.",
                        content:
                            "• Normal: 95% - 100%\n• Warning: 91% - 94%\n• Critical: Below 90%\n\nWHAT TO DO:\nIf levels are low (Hypoxia), sit upright and take deep breaths. If below 90%, seek medical attention.",
                        canMeasure: true,
                      ),
                      _buildTipCard(
                        context,
                        icon: Icons.favorite_rounded,
                        color: Colors.red,
                        title: "Heart Rate",
                        subtitle: "Pulse Beats per Minute",
                        instruction:
                            "This is measured automatically alongside SpO2 or Blood Pressure. Just remain calm and still.",
                        content:
                            "• Resting: 60 - 100 bpm\n• Athletes: 40 - 60 bpm\n• High (Tachycardia): > 100 bpm\n\nFACT:\nStress, caffeine, dehydration, and infection can raise your heart rate.",
                        canMeasure: true,
                      ),
                      _buildTipCard(
                        context,
                        icon: Icons.thermostat_rounded,
                        color: Colors.orange,
                        title: "Body Temperature",
                        subtitle: "Fever Detection",
                        instruction:
                            "Stand in front of the kiosk. Ensure your forehead is visible (remove hats/hair). Position about 5-10cm from the sensor.",
                        content:
                            "• Normal: 36.5°C - 37.5°C\n• Fever: 38.0°C and above\n• Hypothermia: Below 35.0°C\n\nNOTE:\nUsually indicates infection. Drink plenty of fluids. Seek help if > 39°C.",
                        canMeasure: true,
                      ),
                      _buildTipCard(
                        context,
                        icon: Icons.scale_rounded,
                        color: Colors.purple,
                        title: "BMI & Weight",
                        subtitle: "Body Composition",
                        instruction:
                            "Remove heavy shoes or bags. Stand straight on the platform. Enter your height manually using the screen slider.",
                        content:
                            "• Underweight: < 18.5\n• Normal: 18.5 - 24.9\n• Overweight: 25 - 29.9\n• Obese: 30.0 and above\n\nFORMULA:\nWeight (kg) / Height (m)².",
                        canMeasure: true,
                      ),
                      _buildTipCard(
                        context,
                        icon: Icons.self_improvement_rounded,
                        color: Colors.green,
                        title: "Daily Habits",
                        subtitle: "Wellness Checklist",
                        instruction:
                            "These are general recommendations for a healthy lifestyle on the island.",
                        content:
                            "• Hydration: Drink 8-10 glasses of water daily.\n• Sleep: Aim for 7-9 hours of quality sleep.\n• Activity: 30 mins moderate exercise.",
                        canMeasure: false,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 40),

              // --- 5. ISLAND HEALTHY LIVING (FIXED: Uses _buildMiniGuide) ---
              const Text("Island Healthy Living",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _buildMiniGuide(
                          Icons.rice_bowl_rounded,
                          "Eat Root Crops",
                          "Choose Kamote/Cassava over white rice for better fiber.")),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildMiniGuide(
                          Icons.set_meal_rounded,
                          "Fresh over Canned",
                          "Fresh fish has less sodium than canned goods.")),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildMiniGuide(
                          Icons.local_drink_rounded,
                          "Stay Hydrated",
                          "Heat exhaustion is common. Drink water often.")),
                ],
              ),

              const SizedBox(height: 60),

              // --- 6. FOOTER INFO ---
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user_outlined,
                          color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      const Text(
                        "Reference: World Health Organization (WHO) Guidelines.\nFor medical advice, always consult a licensed doctor.",
                        style: TextStyle(
                            color: Colors.grey, fontSize: 14, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSymptomRow() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildSymptomChip("Dizzy / Headache", Icons.speed_rounded, Colors.blue),
        _buildSymptomChip(
            "Fever / Hot", Icons.thermostat_rounded, Colors.orange),
        _buildSymptomChip("Short Breath", Icons.air_rounded, Colors.cyan),
        _buildSymptomChip("Palpitations", Icons.favorite_rounded, Colors.red),
        _buildSymptomChip("Weight Change", Icons.scale_rounded, Colors.purple),
      ],
    );
  }

  Widget _buildSymptomChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHeroTip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandGreen, AppColors.brandGreenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandGreen.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emergency_rounded,
                size: 56, color: Colors.white),
          ),
          const SizedBox(width: 32),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Emergency Assistance",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                SizedBox(height: 8),
                Text(
                  "For severe symptoms like chest pain, difficulty breathing, or loss of consciousness, contact the Barangay Health Center immediately.",
                  style:
                      TextStyle(fontSize: 18, color: Colors.white, height: 1.4),
                ),
                SizedBox(height: 16),
                Text(
                  "Hotline: 0917-123-4567  •  Rescue Boat: 0918-987-6543",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED: Now accepts dynamic content from _getRealTimeAlert
  Widget _buildSeasonalAlert(BuildContext context, IconData icon, Color color,
      String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05), // Lighter bg
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "CURRENT ALERT: $title",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 4),
                // FIXED: Added const to satisfy 'prefer_const_constructors'
                Text(
                  desc,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Reuse Mini Guide (FIXED: Now used in the build method)
  Widget _buildMiniGuide(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ]),
      child: Column(
        children: [
          Icon(icon, color: AppColors.brandGreen, size: 32),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.brandDark),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(desc,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildTipCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String instruction,
    required String content,
    bool canMeasure = false,
  }) {
    return FlowAnimatedButton(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => _buildDetailDialog(
                    ctx, icon, color, title, instruction, content, canMeasure),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(icon, color: color, size: 36),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 18, color: Colors.grey[300]),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandDark),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 16, color: Colors.grey[600], height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailDialog(BuildContext context, IconData icon, Color color,
      String title, String instruction, String content, bool canMeasure) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 10,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 40, color: color),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // INSTRUCTION SECTION
                      const Text("HOW TO MEASURE",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.brandGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color:
                                  AppColors.brandGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: AppColors.brandGreen),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                instruction,
                                style: const TextStyle(
                                    fontSize: 18,
                                    height: 1.5,
                                    color: AppColors.brandDark),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // DETAILS SECTION
                      const Text("INTERPRETING RESULTS",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          content,
                          style: const TextStyle(
                              fontSize: 18, height: 1.6, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        foregroundColor: Colors.grey[700],
                      ),
                      child: const Text("Close",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (canMeasure) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          context.push(AppRoutes.healthWizard); // Go to wizard
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text("Start Checkup Now",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
