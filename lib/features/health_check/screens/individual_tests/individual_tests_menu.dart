import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/config/routes.dart';
import '../../../../core/widgets/kiosk_scaffold.dart';
import '../../../../core/widgets/flow_animated_button.dart';

class IndividualTestsMenu extends StatelessWidget {
  const IndividualTestsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return KioskScaffold(
      title: "Select a Test",
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(32),
            children: [
              const Text(
                "Quick Check",
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Choose a specific vital sign to measure immediately.",
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              LayoutBuilder(builder: (context, constraints) {
                return GridView.count(
                  crossAxisCount: constraints.maxWidth > 700 ? 2 : 1,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio: 2.0, // Wide, easy to tap cards
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildTestCard(
                      context,
                      "Body Temperature",
                      "Check for fever",
                      Icons.thermostat_rounded,
                      Colors.orange,
                      AppRoutes.testTemperature,
                    ),
                    _buildTestCard(
                      context,
                      "Blood Pressure",
                      "Monitor hypertension",
                      Icons.speed_rounded,
                      Colors.blue,
                      AppRoutes.testBloodPressure,
                    ),
                    _buildTestCard(
                      context,
                      "Heart Rate",
                      "Pulse check",
                      Icons.favorite_rounded,
                      Colors.red,
                      AppRoutes.testHeartRate,
                    ),
                    _buildTestCard(
                      context,
                      "Oxygen Saturation",
                      "Lung health check",
                      Icons.air_rounded,
                      Colors.cyan,
                      AppRoutes.testOxygen,
                    ),
                    _buildTestCard(
                      context,
                      "BMI & Weight",
                      "Body composition",
                      Icons.scale_rounded,
                      Colors.purple,
                      AppRoutes.testBmi,
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestCard(BuildContext context, String title, String subtitle,
      IconData icon, Color color, String route) {
    return FlowAnimatedButton(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => context.push(route),
            splashColor: color.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 48, color: color),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.grey[300], size: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
