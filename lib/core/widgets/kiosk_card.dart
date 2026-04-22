import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class HeroSplitCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const HeroSplitCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Background
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32), // More rounded for premium feel
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.premiumGreenGradient,
              stops: [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandGreen.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
        ),
        // 2. Watermark
        Positioned(
          right: -20,
          bottom: -20,
          child: Transform.rotate(
            angle: -0.2,
            child: Icon(icon,
                size: 160, color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        // 3. Ripple & Tap Layer
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: SizedBox.expand(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5)),
                        ],
                      ),
                      child: Icon(icon, color: AppColors.brandGreen, size: 38),
                    ),
                    const Spacer(),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        shadows: [
                          Shadow(
                              offset: Offset(0, 2),
                              blurRadius: 4,
                              color: Colors.black12)
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Tap to start",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 14),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class StandardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const StandardCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.08), width: 1.5),
        boxShadow: AppColors.premiumShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: AppColors.brandGreen.withValues(alpha: 0.1),
          highlightColor: AppColors.brandGreen.withValues(alpha: 0.05),
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.brandGreenLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 40, color: AppColors.brandGreen),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
