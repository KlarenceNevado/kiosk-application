import 'dart:ui';
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
import '../../auth/domain/i_auth_repository.dart';
import '../../auth/models/user_model.dart';
import '../../user_history/domain/i_history_repository.dart';
import '../../health_check/models/vital_signs_model.dart';
import 'package:intl/intl.dart';


class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  void _showProfileDialog(BuildContext context, User? user, VitalSigns? lastRecord) {

    if (user == null) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Profile",
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: anim1,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: 600,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: AppColors.brandGreen.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // --- HEADER SECTION ---
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.brandGreen,
                                      AppColors.brandGreenDark,
                                    ],
                                  ),

                                ),
                                child: const CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.white,
                                  child: Icon(Icons.person_rounded,
                                      color: AppColors.brandGreen, size: 48),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.fullName,
                                      style: AppTextStyles.h1.copyWith(
                                        color: AppColors.brandDark,
                                        fontSize: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.brandGreen
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            user.isSynced ? Icons.cloud_done : Icons.cloud_off_rounded,
                                            size: 14,
                                            color: user.isSynced ? AppColors.brandGreen : Colors.orange,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            user.isSynced ? "SYNCED" : "OFFLINE",
                                            style: TextStyle(
                                              color: user.isSynced ? AppColors.brandGreenDark : Colors.orange[800],
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
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
                          const SizedBox(height: 40),

                          // --- DETAILS GRID ---
                          GridView.count(
                            shrinkWrap: true,
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 2.2,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildInfoCard(Icons.cake_outlined, "Age", "${user.age} Years Old"),
                              _buildInfoCard(Icons.wc_outlined, "Gender", user.gender),
                              _buildInfoCard(Icons.location_on_outlined, "Sitio", user.sitio),
                              _buildInfoCard(
                                Icons.calendar_month_outlined, 
                                "Last Checkup", 
                                lastRecord != null 
                                  ? DateFormat('MMM dd, yyyy').format(lastRecord.timestamp) 
                                  : "No Record Yet"
                              ),
                            ],
                          ),


                          const SizedBox(height: 48),

                          // --- ACTIONS ---
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: FlowAnimatedButton(
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.brandGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16)),
                                      elevation: 0,
                                    ),
                                    child: const Text("CLOSE",
                                        style: TextStyle(
                                            letterSpacing: 1.2,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 1,
                                child: FlowAnimatedButton(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await context.read<IAuthRepository>().logout();
                                      if (context.mounted) {
                                        context.go(AppRoutes.login);
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.redAccent, width: 2),
                                      foregroundColor: Colors.redAccent,
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: const Text("LOGOUT",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],

      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brandGreen, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // FIXED: Safely access localization or provide fallbacks
    final loc = AppLocalizations.of(context);

    // Get Current User Name
    final currentUser = context.watch<IAuthRepository>().currentUser;
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
                                    onTap: () async {
                                      // Pre-load history to get last record
                                      final history = context.read<IHistoryRepository>();
                                      await history.loadUserHistory(currentUser!.id);
                                      final lastRecord = history.records.isNotEmpty ? history.records.first : null;
                                      
                                      if (context.mounted) {
                                        _showProfileDialog(context, currentUser, lastRecord);
                                      }
                                    },
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
                      await context.read<IAuthRepository>().logout();
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
