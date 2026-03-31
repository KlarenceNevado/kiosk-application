import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// CORE
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/vital_validator.dart';
import '../../../core/widgets/flow_animated_button.dart';

// MODEL
import '../../health_check/models/vital_signs_model.dart';

class HistoryItemTile extends StatelessWidget {
  final VitalSigns data;
  final VoidCallback onTap;

  const HistoryItemTile({
    super.key,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String dateString = DateFormat.yMMMd().format(data.timestamp);
    final String timeString = DateFormat.jm().format(data.timestamp);

    // Evaluate overall status (Identify if any metric is critical)
    bool isAlert = false;
    if (data.systolicBP > 0 &&
        VitalValidator.evaluateBP(data.systolicBP, data.diastolicBP).status ==
            HealthStatus.critical) {
      isAlert = true;
    }
    if (data.heartRate > 0 &&
        VitalValidator.evaluateHR(data.heartRate).status ==
            HealthStatus.critical) {
      isAlert = true;
    }
    if (data.oxygen > 0 &&
        VitalValidator.evaluateSpO2(data.oxygen).status ==
            HealthStatus.critical) {
      isAlert = true;
    }

    return FlowAnimatedButton(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: isAlert
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
              border: Border.all(
                color: isAlert
                    ? Colors.orange.withValues(alpha: 0.5)
                    : Colors.grey.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              children: [
                // Header Row: Date & Time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.brandGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dateString,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandGreenDark,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeString,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    _buildStatusBadge(data.status),
                    if (isAlert) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 20),
                    ],
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: Colors.grey),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 16),

                // Vitals Summary Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildCompactVital(
                            Icons.favorite_rounded,
                            Colors.red,
                            data.heartRate,
                            "bpm",
                          ),
                        ),
                        Expanded(
                          child: _buildCompactVital(
                            Icons.speed_rounded,
                            Colors.blue,
                            data.systolicBP,
                            "mmHg",
                            secondaryValue: data.diastolicBP,
                          ),
                        ),
                        Expanded(
                          child: _buildCompactVital(
                            Icons.air_rounded,
                            Colors.cyan,
                            data.oxygen,
                            "%",
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactVital(IconData icon, Color color, int value, String unit,
      {int? secondaryValue}) {
    String display = "N/A";
    bool hasData = value > 0;

    if (hasData) {
      if (secondaryValue != null) {
        display = "$value/$secondaryValue";
      } else {
        display = "$value";
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            color: hasData ? color : Colors.grey.withValues(alpha: 0.3),
            size: 18),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            display,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: hasData
                  ? AppColors.brandDark
                  : Colors.grey.withValues(alpha: 0.5),
            ),
          ),
        ),
        Text(unit, 
          style: TextStyle(
            fontSize: 9, 
            color: Colors.grey[500],
            letterSpacing: -0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final bool isVerified = status == 'verified' || status == 'verified_true';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isVerified ? AppColors.brandGreen : Colors.orange).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isVerified ? AppColors.brandGreen : Colors.orange).withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.check_circle_rounded : Icons.pending_rounded,
            size: 12,
            color: isVerified ? AppColors.brandGreen : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            isVerified ? "Verified" : "Reviewing",
            style: TextStyle(
              color: isVerified ? AppColors.brandGreen : Colors.orange,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
