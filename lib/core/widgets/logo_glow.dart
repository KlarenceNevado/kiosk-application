import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class LogoGlow extends StatefulWidget {
  final double size;
  final Color glowColor;
  final Widget? child;

  const LogoGlow({
    super.key,
    this.size = 180.0,
    this.glowColor = AppColors.brandGreen,
    this.child,
  });

  @override
  State<LogoGlow> createState() => _LogoGlowState();
}

class _LogoGlowState extends State<LogoGlow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), 
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1: Subtle outer aura
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.glowColor.withValues(alpha: 0.1),
                    blurRadius: 50,
                    spreadRadius: 10.0,
                  ),
                ],
              ),
            ),
            // Layer 2: Soft core glow
            Container(
              width: widget.size * 0.77,
              height: widget.size * 0.77,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.glowColor.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 2.0,
                  ),
                ],
              ),
            ),
            // Layer 3: Solid White container
            Container(
              padding: EdgeInsets.all(widget.size * 0.15),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 15,
                    offset: Offset(0, 6),
                  )
                ],
              ),
              child: widget.child ?? Image.asset(
                'assets/icons/patient_icon.png',
                width: widget.size * 0.4,
                height: widget.size * 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
