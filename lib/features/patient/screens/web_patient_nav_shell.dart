import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../auth/data/web_auth_repository.dart';
import '../data/mobile_navigation_provider.dart';
import '../../user_history/data/web_history_repository.dart';
import 'web_patient_dashboard_screen.dart';

/// Web-safe navigation shell for the Patient Mobile PWA.
/// Does NOT import SyncService, NotificationService, or any dart:io code.
class WebPatientNavShell extends StatelessWidget {
  const WebPatientNavShell({super.key});

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<MobileNavigationProvider>();
    final currentIndex = navProvider.currentIndex;

    const List<Widget> screens = [
      WebPatientDashboardScreen(),
      _WebHistoryTab(),
      _WebChatTab(),
      _WebAnnouncementsTab(),
      _WebProfileTab(),
    ];

    return Scaffold(
      body: _FadeIndexedStack(
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
              selectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.bold),
              iconSize: 28,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.dashboard_rounded),
                  ),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.history_rounded),
                  ),
                  label: 'History',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.chat_bubble_outline_rounded),
                  ),
                  label: 'Inbox',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.campaign_outlined),
                  ),
                  label: 'Announcements',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
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

/// History Tab — loads from Supabase
class _WebHistoryTab extends StatefulWidget {
  const _WebHistoryTab();

  @override
  State<_WebHistoryTab> createState() => _WebHistoryTabState();
}

class _WebHistoryTabState extends State<_WebHistoryTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthRepository>().currentUser;
      if (user != null) {
        context.read<HistoryRepository>().loadUserHistory(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyRepo = context.watch<HistoryRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Health History",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.brandGreen,
        automaticallyImplyLeading: false,
      ),
      body: historyRepo.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandGreen))
          : historyRepo.records.isEmpty
              ? const Center(
                  child: Text("No records yet.",
                      style: TextStyle(color: Colors.grey, fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: historyRepo.records.length,
                  itemBuilder: (context, i) {
                    final v = historyRepo.records[i];
                    final date =
                        "${v.timestamp.year}-${v.timestamp.month.toString().padLeft(2, '0')}-${v.timestamp.day.toString().padLeft(2, '0')}";
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: const Icon(Icons.monitor_heart_rounded,
                            color: AppColors.brandGreen),
                        title: Text(date,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            "BP ${v.systolicBP}/${v.diastolicBP} · HR ${v.heartRate} · SpO2 ${v.oxygen}%"),
                      ),
                    );
                  },
                ),
    );
  }
}

/// Chat Tab (placeholder for web)
class _WebChatTab extends StatelessWidget {
  const _WebChatTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.brandGreen,
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 64),
            SizedBox(height: 16),
            Text("Chat coming soon to the web!",
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            SizedBox(height: 8),
            Text(
                "For now, please use the mobile app for real-time messaging.",
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// Announcements Tab
class _WebAnnouncementsTab extends StatelessWidget {
  const _WebAnnouncementsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Announcements",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.brandGreen,
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, color: Colors.grey, size: 64),
            SizedBox(height: 16),
            Text("Announcements coming soon!",
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/// Profile Tab
class _WebProfileTab extends StatelessWidget {
  const _WebProfileTab();

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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
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
            const SizedBox(height: 32),
            _buildInfoTile(Icons.phone, "Phone", user?.phoneNumber ?? "--"),
            _buildInfoTile(
                Icons.badge, "ID", user?.id.substring(0, 8) ?? "--"),
            const SizedBox(height: 40),
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
                  context.read<MobileNavigationProvider>().reset();
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
}

class _FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _FadeIndexedStack({
    required this.index,
    required this.children,
  });

  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _controller.forward();
  }

  @override
  void didUpdateWidget(_FadeIndexedStack oldWidget) {
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
