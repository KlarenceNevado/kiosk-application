import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'flow_animated_button.dart';

class StatusPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final Color? iconColor;

  const StatusPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onButtonPressed,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big Icon
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 80, color: iconColor ?? Colors.grey[400]),
          ),
          const SizedBox(height: 24),

          // Texts
          Text(
            title,
            style: AppTextStyles.h1
                .copyWith(color: Colors.grey[600], fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),

          // Optional Button
          if (buttonText != null && onButtonPressed != null) ...[
            const SizedBox(height: 40),
            FlowAnimatedButton(
              child: Material(
                color: AppColors.brandGreen,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  onTap: onButtonPressed,
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    child: Text(buttonText!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
