import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'flow_animated_button.dart';

class KioskScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showBackButton;
  // NEW: Allows custom back behavior (e.g., stopping sensors)
  final VoidCallback? onBackTap;

  const KioskScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showBackButton = true,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: showBackButton
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: FlowAnimatedButton(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.brandDark),
                      // FIXED: Use custom callback if provided, else pop
                      onPressed: onBackTap ?? () => context.pop(),
                    ),
                  ),
                ),
              )
            : null,
        title: Text(title, style: AppTextStyles.h1.copyWith(fontSize: 24)),
        actions: actions,
      ),
      body: body,
    );
  }
}
