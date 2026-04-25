import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../auth/domain/i_auth_repository.dart';
import '../../auth/models/user_model.dart';
import '../../health_check/models/vital_signs_model.dart';
import '../../../../core/utils/health_thresholds.dart';

class AdminRecentActivity extends StatelessWidget {
  final List<VitalSigns> records;

  const AdminRecentActivity({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Recent Activity",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark)),
              Icon(Icons.history, color: Colors.grey)
            ],
          ),
          const SizedBox(height: 24),
          if (records.isEmpty)
            const Text("No recent activity.",
                style: TextStyle(color: Colors.grey))
          else
            ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.length > 10 ? 10 : records.length,
                separatorBuilder: (context, index) => const Divider(height: 32),
                itemBuilder: (context, index) {
                  final record = records[index];
                  final user = context.read<IAuthRepository>().users.firstWhere(
                      (u) => u.id == record.userId,
                      orElse: () => User.empty());

                  final status = HealthThresholds.isCritical(user, record) ? "Abnormal" : "Normal";

                  return Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.monitor_heart,
                          color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text("${user.firstName} completed a check",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                              "${record.timestamp.day}/${record.timestamp.month}/${record.timestamp.year} at ${record.timestamp.hour}:${record.timestamp.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ])),
                    SizedBox(
                      width: 70,
                      child: Text(
                        status,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: status == "Normal"
                                ? AppColors.brandGreen
                                : Colors.red),
                      ),
                    )
                  ]);
                })
        ],
      ),
    );
  }
}
