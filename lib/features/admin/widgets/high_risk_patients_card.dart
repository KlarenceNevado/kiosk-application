import 'package:flutter/material.dart';
import '../../auth/models/user_model.dart';
import '../../health_check/models/vital_signs_model.dart';
import '../../../core/constants/app_colors.dart';

class HighRiskPatientsCard extends StatelessWidget {
  final List<User> users;
  final List<VitalSigns> records;

  const HighRiskPatientsCard({
    super.key,
    required this.users,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Find the latest record for each user
    final Map<String, VitalSigns> latestUserRecords = {};

    // Sort records by timestamp descending so the first one we see is the newest
    final sortedRecords = List<VitalSigns>.from(records)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    for (var r in sortedRecords) {
      if (!latestUserRecords.containsKey(r.userId)) {
        latestUserRecords[r.userId] = r;
      }
    }

    // 2. Filter for high risk (Systolic > 140 OR SpO2 < 90)
    final List<Map<String, dynamic>> highRiskProfiles = [];

    for (var user in users) {
      final latest = latestUserRecords[user.id];
      if (latest != null) {
        bool isHypertensive = latest.systolicBP > 140;
        bool isHypoxic = latest.oxygen < 90;

        if (isHypertensive || isHypoxic) {
          highRiskProfiles.add({
            'user': user,
            'vitals': latest,
            'reasons': [
              if (isHypertensive)
                "High BP (${latest.systolicBP}/${latest.diastolicBP})",
              if (isHypoxic) "Low O2 (${latest.oxygen}%)"
            ],
          });
        }
      }
    }

    if (highRiskProfiles.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.brandGreen.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.brandGreen.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.brandGreen, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("System Status: Healthy",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandDark)),
                  Text("All screened patients are within normal thresholds.",
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.red.shade100.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    "Triage: Attention",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${highRiskProfiles.length}",
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                )
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: highRiskProfiles.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.red.shade200),
            itemBuilder: (context, index) {
              final profile = highRiskProfiles[index];
              final user = profile['user'] as User;
              final reasons = profile['reasons'] as List<String>;

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text(
                  user.fullName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: reasons
                        .map((r) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border:
                                      Border.all(color: Colors.red.shade300)),
                              child: Text(r,
                                  style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ))
                        .toList(),
                  ),
                ),
                trailing: TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            "Broadcast Inbox capability coming in next phase!")));
                  },
                  icon: const Icon(Icons.campaign, size: 18),
                  label: const Text("Alert"),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.red.shade200),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }
}
