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
import '../../../../core/providers/language_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/models/user_model.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  void _showProfileDialog(BuildContext context, User? user) {
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.brandGreen,
                child: Icon(Icons.person, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 24),
              Text(user.fullName,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark)),
              const SizedBox(height: 8),
              Text("ID: ${user.id.substring(0, 10).toUpperCase()}...",
                  style: TextStyle(color: Colors.grey[600], fontSize: 16)),
              const Divider(height: 48),
              _buildProfileRow(Icons.location_on_outlined, "Location", user.sitio),
              const SizedBox(height: 16),
              _buildProfileRow(Icons.phone_outlined, "Phone Number", user.phoneNumber),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("CLOSE",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.brandGreen, size: 24),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDark)),
          ],
        ),
      ],
    );
  }

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
            const Expanded(
              flex: 5,
              child: Center(
              child: SizedBox.shrink(),
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
                                InkWell(
                                  onTap: () => _showProfileDialog(context, currentUser),
                                  borderRadius: BorderRadius.circular(c.maxHeight),
                                  child: Icon(Icons.account_circle_outlined,
                                      size: c.maxHeight * 0.7,
                                      color: Colors.grey[600]),
                                ),
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
