import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FlowAnimatedButton extends StatefulWidget {
  final Widget child;
  final bool isDisabled;

  const FlowAnimatedButton({
    super.key,
    required this.child,
    this.isDisabled = false,
  });

  @override
  State<FlowAnimatedButton> createState() => _FlowAnimatedButtonState();
}

class _FlowAnimatedButtonState extends State<FlowAnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDisabled) {
      return widget.child;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => HapticFeedback.selectionClick(),
      child: Listener(
        onPointerDown: (_) {
          HapticFeedback.lightImpact();
          _controller.forward();
        },
        onPointerUp: (_) => _controller.reverse(),
        onPointerCancel: (_) => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
