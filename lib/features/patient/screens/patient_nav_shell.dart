import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/models/user_model.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../mobile/screens/mobile_history_screen.dart';
import 'patient_dashboard_screen.dart';
import 'patient_announcements_screen.dart';
import '../../chat/screens/patient_chat_screen.dart';
import '../../chat/data/chat_repository.dart';
import '../data/mobile_navigation_provider.dart';

/// The unified navigation shell for the Patient Mobile App.
/// 4 tabs: Dashboard, History, Announcements, Profile
class PatientNavShell extends StatelessWidget {
  const PatientNavShell({super.key});

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<MobileNavigationProvider>();
    final currentIndex = navProvider.currentIndex;

    const List<Widget> screens = [
      PatientDashboardScreen(),
      MobileHistoryScreen(),
      PatientChatScreen(), // NEW TAB
      PatientAnnouncementsScreen(),
      _PatientProfileTab(),
    ];

    return Scaffold(
      body: FadeIndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70,
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (index) => navProvider.setIndex(index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: AppColors.brandGreen,
              unselectedItemColor: Colors.grey.shade400,
              selectedFontSize: 13,
              unselectedFontSize: 12,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              iconSize: 28,
              elevation: 0,
              items: [
                const BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.dashboard_rounded),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.dashboard_rounded),
                  ),
                  label: 'Dashboard',
                ),
                const BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.history_rounded),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.history_rounded),
                  ),
                  label: 'History',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Badge(
                      label: Consumer<ChatRepository>(
                        builder: (context, repo, _) =>
                            Text("${repo.messages.length}"),
                      ),
                      isLabelVisible: false, // For now
                      child: const Icon(Icons.chat_bubble_outline_rounded),
                    ),
                  ),
                  activeIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.chat_bubble_rounded),
                  ),
                  label: 'Inbox',
                ),
                const BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.campaign_outlined),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.campaign_rounded),
                  ),
                  label: 'Announcements',
                ),
                const BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.person_rounded),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.person_rounded),
                  ),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile tab — shows user info and logout button.
class _PatientProfileTab extends StatelessWidget {
  const _PatientProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthRepository>().currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("My Profile",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.brandGreen,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Avatar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person,
                  size: 64, color: AppColors.brandGreen),
            ),
            const SizedBox(height: 20),
            Text(
              user?.fullName ?? "Patient",
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandDark),
            ),
            const SizedBox(height: 4),
            Text(
              user?.sitio.isNotEmpty == true ? "Sitio ${user!.sitio}" : "",
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            if ((user?.gender ?? '').isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brandGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user!.gender,
                  style: const TextStyle(
                      color: AppColors.brandGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
            const SizedBox(height: 24),

            _buildLinkedAccountsSection(context),
            const SizedBox(height: 24),

            if (user != null)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_2_rounded,
                      color: Colors.white, size: 24),
                  label: const Text("Show Login QR Code",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: AppColors.brandDark.withValues(alpha: 0.3),
                  ),
                  onPressed: () => _showQrDialog(context, user),
                ),
              ),

            const SizedBox(height: 32),

            // Info Cards
            _buildInfoTile(
                Icons.cake,
                "Date of Birth",
                user != null
                    ? "${user.dateOfBirth.year}-${user.dateOfBirth.month.toString().padLeft(2, '0')}-${user.dateOfBirth.day.toString().padLeft(2, '0')}"
                    : "--"),
            _buildInfoTile(
                Icons.location_on, "Sitio / Zone", user?.sitio ?? "--"),
            _buildInfoTile(
                Icons.phone, "Phone Number", user?.phoneNumber ?? "--"),
            _buildInfoTile(
                Icons.badge, "Patient ID", user?.id.substring(0, 8) ?? "--"),

            const SizedBox(height: 40),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text("LOGOUT",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  await context.read<AuthRepository>().logout();
                  if (context.mounted) {
                    context.go('/patient/login');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedAccountsSection(BuildContext context) {
    final authRepo = context.watch<AuthRepository>();
    final linkedAccounts = authRepo.getLinkedAccounts();
    final currentUser = authRepo.currentUser;

    if (currentUser == null) return const SizedBox.shrink();

    // Check if the current user is a "primary" user or someone who has a primary user
    final primaryParentId = currentUser.parentId ?? currentUser.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Family & Dependents",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDark)),
            TextButton.icon(
              onPressed: () => _showAddDependentDialog(
                  context, currentUser, primaryParentId),
              icon: const Icon(Icons.add_circle_outline,
                  color: AppColors.brandGreen, size: 20),
              label: const Text("Add",
                  style: TextStyle(
                      color: AppColors.brandGreen,
                      fontWeight: FontWeight.bold)),
            )
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: linkedAccounts.map((account) {
              final isCurrent = account.id == currentUser.id;
              final isPrimary = account.parentId == null;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      isCurrent ? AppColors.brandGreen : Colors.grey.shade200,
                  child: Icon(Icons.person,
                      color: isCurrent ? Colors.white : Colors.grey.shade600),
                ),
                title: Text(account.fullName,
                    style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(isPrimary ? "Primary Account" : "Dependent"),
                trailing: isCurrent
                    ? const Icon(Icons.check_circle,
                        color: AppColors.brandGreen)
                    : null,
                onTap: () {
                  if (!isCurrent) {
                    authRepo.switchUser(account);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showAddDependentDialog(
      BuildContext context, User activeUser, String parentId) {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final dobCtrl = TextEditingController();
    String selectedGender = "Male";

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Add Dependent"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      "Dependents will share your Phone Number and PIN for secure access.",
                      style: TextStyle(
                          color: Colors.grey, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: firstCtrl,
                    decoration: const InputDecoration(
                        labelText: "First Name", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lastCtrl,
                    decoration: const InputDecoration(
                        labelText: "Last Name", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dobCtrl,
                    decoration: const InputDecoration(
                        labelText: "Date of Birth (YYYY-MM-DD)",
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGender,
                    decoration: const InputDecoration(
                        labelText: "Gender", border: OutlineInputBorder()),
                    items: ["Male", "Female", "Other"].map((g) {
                      return DropdownMenuItem(value: g, child: Text(g));
                    }).toList(),
                    onChanged: (val) => setState(() => selectedGender = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (firstCtrl.text.isEmpty ||
                      lastCtrl.text.isEmpty ||
                      dobCtrl.text.isEmpty) {
                    return; // Handle validation elegantly in prod
                  }

                  final newDep = User(
                    id: const Uuid().v4(),
                    firstName: firstCtrl.text,
                    lastName: lastCtrl.text,
                    middleInitial: "",
                    sitio: activeUser.sitio, // Inherit from parent
                    phoneNumber: activeUser.phoneNumber, // Inherit from parent
                    pinCode: activeUser.pinCode, // Inherit from parent
                    dateOfBirth: DateTime.parse(dobCtrl.text),
                    gender: selectedGender,
                    parentId: parentId, // Establish Link!
                  );

                  // Call backend directly (for demo simplicity, avoiding provider scopes overhead inside dialog)
                  await ctx.read<AuthRepository>().registerUser(newDep);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text("Dependent added successfully.")));
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen),
                child:
                    const Text("Create", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brandGreen, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandDark)),
            ],
          ),
        ],
      ),
    );
  }

  void _showQrDialog(BuildContext context, User user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 32),
              const Text("Your Login QR Code",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark)),
              const SizedBox(height: 8),
              const Text(
                  "Hold this in front of the Kiosk camera to log in instantly.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 24,
                          offset: const Offset(0, 8))
                    ]),
                child: QrImageView(
                  data: '{"action":"login","userId":"${user.id}"}',
                  version: QrVersions.auto,
                  size: 200.0,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.circle, color: AppColors.brandDark),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: AppColors.brandDark),
                ),
              ),
              const SizedBox(height: 32),
              Text(user.fullName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              Text("ID: ${user.id.substring(0, 8)}",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
  }

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    if (widget.index != oldWidget.index) {
      _controller.forward(from: 0.0);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: IndexedStack(
        index: widget.index,
        children: widget.children,
      ),
    );
  }
}
