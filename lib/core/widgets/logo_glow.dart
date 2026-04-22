import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/system/app_environment.dart';

class LogoGlow extends StatefulWidget {
  final double size;
  final Color glowColor;
  final Widget? child;
  final bool animate;

  const LogoGlow({
    super.key,
    this.size = 180.0,
    this.glowColor = AppColors.brandGreen,
    this.child,
    this.animate = true,
  });

  @override
  State<LogoGlow> createState() => _LogoGlowState();
}

class _LogoGlowState extends State<LogoGlow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), 
    );

    // Initial state check
    if (widget.animate && !AppEnvironment().isEcoModeActive.value) {
      _controller.repeat(reverse: true);
    }

    // Listen to Eco Mode changes
    AppEnvironment().isEcoModeActive.addListener(_handleEcoChange);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  void _handleEcoChange() {
    if (widget.animate) {
      if (AppEnvironment().isEcoModeActive.value) {
        _controller.stop();
      } else {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    AppEnvironment().isEcoModeActive.removeListener(_handleEcoChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: const AlwaysStoppedAnimation(1.0),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Layer 1: Subtle outer aura
                Container(
                  width: widget.size * _pulseAnimation.value,
                  height: widget.size * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.glowColor.withValues(alpha: 0.08),
                        blurRadius: 60,
                        spreadRadius: 20 * _pulseAnimation.value,
                      ),
                    ],
                  ),
                ),
                // Layer 2: Core glow
                Container(
                  width: widget.size * 0.77,
                  height: widget.size * 0.77,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.glowColor.withValues(alpha: 0.12),
                        blurRadius: 40,
                        spreadRadius: 5.0 * _pulseAnimation.value,
                      ),
                    ],
                  ),
                ),
                // Layer 3: Main container
                Container(
                  padding: EdgeInsets.all(widget.size * 0.15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
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
      },
    );
  }
}
