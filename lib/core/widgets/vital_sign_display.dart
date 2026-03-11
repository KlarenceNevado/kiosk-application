import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class VitalSignDisplay extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;

  const VitalSignDisplay({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Icon Circle
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 8),

        // Value (Scales down if too long)
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: AppTextStyles.h2.copyWith(
                color: AppColors.brandDark,
                fontSize: 18,
                fontWeight: FontWeight.w800),
          ),
        ),

        // Label + Unit
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            text: "$label\n",
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontFamily: 'Roboto',
                height: 1.2),
            children: [
              TextSpan(
                  text: unit,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}
