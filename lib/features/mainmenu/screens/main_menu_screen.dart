import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// LOCALIZATION
import '../../../../l10n/app_localizations.dart';

// CORE
import '../../../core/config/routes.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/flow_animated_button.dart';
import '../../../core/widgets/kiosk_card.dart';
import '../../../core/widgets/system_pill.dart';

// STATE
import '../../../../main_kiosk.dart'; // LanguageProvider
import '../../auth/data/auth_repository.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // FIXED: Safely access localization or provide fallbacks
    final loc = AppLocalizations.of(context);

    // Get Current User Name
    final currentUser = context.watch<AuthRepository>().currentUser;
    final String firstName = currentUser?.firstName ?? "Guest";

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // --- TOP BEZEL ---
            Expanded(
              flex: 5,
              child: Center(
                child: Icon(Icons.camera_alt,
                    color: Colors.black.withValues(alpha: 0.1), size: 16),
              ),
            ),

            // --- MAIN INTERFACE ---
            Expanded(
              flex: 85,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: AppColors.brandGreen, width: 8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    children: [
                      // --- HEADER ---
                      Expanded(
                        flex: 12,
                        child: Container(
                          width: double.infinity,
                          color: AppColors.headerBackground,
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: LayoutBuilder(builder: (ctx, c) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  loc?.mainMenuTitle ??
                                      "Barangay Health Kiosk", // Fallback text
                                  style: AppTextStyles.h1
                                      .copyWith(fontSize: c.maxHeight * 0.4),
                                ),
                                Icon(Icons.account_circle_outlined,
                                    size: c.maxHeight * 0.7,
                                    color: Colors.grey[600]),
                              ],
                            );
                          }),
                        ),
                      ),

                      // --- BODY ---
                      Expanded(
                        flex: 88,
                        child: Container(
                          width: double.infinity,
                          color: AppColors.bodyBackground,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // HEADLINE
                              Expanded(
                                flex: 15,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "What would you like to do today, $firstName?",
                                      style: AppTextStyles.displayLarge,
                                    ),
                                  ),
                                ),
                              ),

                              // GRID LAYOUT
                              Expanded(
                                flex: 85,
                                child: Row(
                                  children: [
                                    // COLUMN 1: Hero Button
                                    Expanded(
                                      flex: 40,
                                      child: FlowAnimatedButton(
                                        child: SizedBox.expand(
                                          child: HeroSplitCard(
                                            icon: Icons.monitor_heart,
                                            label: loc?.btnHealthCheck ??
                                                "Full Health Check",
                                            onTap: () => context
                                                .push(AppRoutes.healthWizard),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 24),

                                    // COLUMN 2 & 3: Small Grid
                                    Expanded(
                                      flex: 60,
                                      child: Column(
                                        children: [
                                          // Row 1
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Expanded(
                                                    child: _buildCard(
                                                        Icons.search_rounded,
                                                        loc?.btnTests ??
                                                            "Individual Tests",
                                                        onTap: () => context
                                                            .push(AppRoutes
                                                                .individualTests))),
                                                const SizedBox(width: 24),
                                                Expanded(
                                                    child: _buildCard(
                                                        Icons
                                                            .health_and_safety_rounded,
                                                        loc?.btnHealthTips ??
                                                            "Health Tips",
                                                        onTap: () => context
                                                            .push(AppRoutes
                                                                .healthTips))),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 24),

                                          // Row 2
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: _buildCard(
                                                    Icons.description_outlined,
                                                    loc?.btnHistory ??
                                                        "View History",
                                                    onTap: () => context.push(
                                                        AppRoutes.history),
                                                  ),
                                                ),
                                                const SizedBox(width: 24),
                                                Expanded(
                                                    child: _buildCard(
                                                  Icons.help_outline_rounded,
                                                  loc?.btnHelp ?? "Help & Info",
                                                  onTap: () => context
                                                      .push(AppRoutes.help),
                                                )),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- FOOTER ---
            Expanded(
              flex: 10,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFooterButton(loc?.btnLogout ?? "Logout",
                        onTap: () async {
                      await context.read<AuthRepository>().logout();
                      if (context.mounted) {
                        context.go(AppRoutes.login);
                      }
                    }),
                    const SizedBox(width: 24),
                    _buildFooterButton(
                      Localizations.localeOf(context).languageCode == 'en'
                          ? "Filipino"
                          : "English",
                      onTap: () {
                        context.read<LanguageProvider>().toggleLanguage();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(IconData icon, String label, {VoidCallback? onTap}) {
    return FlowAnimatedButton(
      child: SizedBox.expand(
        child: StandardCard(
          icon: icon,
          label: label,
          onTap: onTap ??
              () {
                debugPrint("Tapped $label");
              },
        ),
      ),
    );
  }

  Widget _buildFooterButton(String label, {VoidCallback? onTap}) {
    return SizedBox(
      height: 48,
      child: FlowAnimatedButton(
        child: SystemPill(
          label: label,
          onTap: onTap ?? () {},
        ),
      ),
    );
  }
}
