import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/routes.dart';
import '../../../core/constants/app_colors.dart';

class SystemInfoScreen extends StatelessWidget {
  const SystemInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("System Information",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.brandDark,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.adminDashboard);
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildInfoCard("App Details", [
            _buildInfoRow("App Name", "Kiosk Health System"),
            _buildInfoRow("Version", "1.0.0+1 (Beta)"),
            _buildInfoRow(
                "Build Date", DateTime.now().toString().split(' ')[0]),
            _buildInfoRow("Environment", "Production"),
          ]),
          const SizedBox(height: 24),
          _buildInfoCard("Device Status", [
            _buildInfoRow("Operating System", "Kiosk OS (Linux/Windows)"),
            _buildInfoRow("Screen Resolution",
                "${MediaQuery.of(context).size.width.toInt()} x ${MediaQuery.of(context).size.height.toInt()}"),
            _buildInfoRow("Storage Status", "Healthy"),
            _buildInfoRow("Database Version", "v4"),
          ]),
          const SizedBox(height: 24),
          _buildInfoCard("Contact Support", [
            _buildInfoRow("Developer", "System Admin"),
            _buildInfoRow("Email", "support@islaverde.health"),
            _buildInfoRow("Hotline", "0917-123-4567"),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandGreen)),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
