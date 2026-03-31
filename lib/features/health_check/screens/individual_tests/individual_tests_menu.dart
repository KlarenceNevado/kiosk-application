import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/config/routes.dart';

class IndividualTestsMenu extends StatelessWidget {
  const IndividualTestsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.brandDark, size: 24), // Enlarged
          onPressed: () => context.pop(),
        ),
        title: const Text("Individual Tests",
            style: TextStyle(
                color: AppColors.brandDark,
                fontWeight: FontWeight.w900,
                fontSize: 20)), // Enlarged
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32), // More room
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select a Specific Test",
              style: TextStyle(
                  fontSize: 36, // High-Accessibility enlargement
                  fontWeight: FontWeight.w900,
                  color: AppColors.brandDark,
                  letterSpacing: -1.0),
            ),
            const SizedBox(height: 8),
            const Text(
              "Pick one of the following to check a specific vital sign.",
              style: TextStyle(
                  fontSize: 18, // Enlarged
                  color: Colors.grey,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 24, // More space
              crossAxisSpacing: 24,
              childAspectRatio: 2.2, // Tighter but larger
              children: [
                _buildTestCard(
                  context,
                  title: "Body Temperature",
                  subtitle: "Check for fever",
                  icon: Icons.thermostat_rounded,
                  color: AppColors.tempOrange,
                  route: AppRoutes.testTemperature,
                  extra: {"type": "temperature"},
                ),
                _buildTestCard(
                  context,
                  title: "Blood Pressure",
                  subtitle: "Monitor hypertension",
                  icon: Icons.speed_rounded,
                  color: AppColors.bpBlue,
                  route: AppRoutes.testBloodPressure,
                  extra: {"type": "blood_pressure"},
                ),
                _buildTestCard(
                  context,
                  title: "Heart Rate",
                  subtitle: "Pulse check",
                  icon: Icons.favorite_rounded,
                  color: AppColors.hrRed,
                  route: AppRoutes.testHeartRate,
                  extra: {"type": "heart_rate"},
                ),
                _buildTestCard(
                  context,
                  title: "Oxygen Saturation",
                  subtitle: "Lung health",
                  icon: Icons.air_rounded,
                  color: AppColors.spO2Cyan,
                  route: AppRoutes.testOxygen,
                  extra: {"type": "oxygen"},
                ),
                _buildTestCard(
                  context,
                  title: "BMI & Weight",
                  subtitle: "Body composition",
                  icon: Icons.scale_rounded,
                  color: Colors.purple,
                  route: AppRoutes.testBmi,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
    Map<String, dynamic>? extra,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // Rounder
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.push(route, extra: extra),
          child: Padding(
            padding: const EdgeInsets.all(24), // Enlarged
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 36), // Enlarged
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontSize: 20, // High-Accessibility enlargement
                            fontWeight: FontWeight.w900,
                            color: AppColors.brandDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 16, // Enlarged
                            color: Colors.grey,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
