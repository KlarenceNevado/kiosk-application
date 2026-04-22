import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AlertBanner extends StatelessWidget {
  final String message;
  final String targetGroup;
  final bool isEmergency;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  const AlertBanner({
    super.key,
    required this.message,
    required this.targetGroup,
    required this.isEmergency,
    required this.onDismiss,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isEmergency ? Colors.red : AppColors.brandDark;
    final icon = isEmergency ? Icons.warning_amber_rounded : Icons.info_outline;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEmergency ? "URGENT ALERT" : "BHW ANNOUNCEMENT",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 20),
                    onPressed: onDismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
