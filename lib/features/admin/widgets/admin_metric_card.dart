import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class AdminMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isMobile;
  final Function(String)? onAction;

  const AdminMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isMobile,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Column(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      if (!isMobile && onAction != null)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_horiz,
                              color: Colors.grey.shade400, size: 20),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          itemBuilder: (context) => [
                            if (title == "Total Residents")
                              const PopupMenuItem(
                                  value: 'users',
                                  child: Row(children: [
                                    Icon(Icons.people, size: 18),
                                    SizedBox(width: 8),
                                    Text("View Resident Registry")
                                  ])),
                            if (title == "Checks Today")
                              const PopupMenuItem(
                                  value: 'validation',
                                  child: Row(children: [
                                    Icon(Icons.fact_check, size: 18),
                                    SizedBox(width: 8),
                                    Text("Open Validation Tab")
                                  ])),
                            if (title == "Alerts")
                              const PopupMenuItem(
                                  value: 'alerts',
                                  child: Row(children: [
                                    Icon(Icons.warning_amber, size: 18),
                                    SizedBox(width: 8),
                                    Text("View All Alerts")
                                  ])),
                          ],
                          onSelected: onAction,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandDark)),
                  const SizedBox(height: 4),
                  Text(title,
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
