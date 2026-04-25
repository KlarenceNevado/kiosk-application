import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/config/routes.dart';
import '../../../core/services/system/config_service.dart';
import '../../../core/services/system/app_environment.dart';
import '../../../core/services/security/admin_security_service.dart';
import '../../../core/widgets/virtual_keyboard.dart';
import '../../user_history/domain/i_history_repository.dart';
import '../data/admin_repository.dart';
import '../../auth/domain/i_auth_repository.dart';
import '../../auth/models/user_model.dart';
import '../../../core/services/database/sync_service.dart';
import '../../../core/services/system/sync_event_bus.dart';
import '../../chat/domain/i_chat_repository.dart';
import '../../../core/utils/health_thresholds.dart';

// NEW TABS
import 'tabs/admin_validation_tab.dart';
import 'tabs/admin_triage_tab.dart';
import 'tabs/admin_broadcast_tab.dart';
import 'tabs/admin_scheduling_tab.dart';
import 'tabs/admin_reports_tab.dart';
import 'tabs/admin_chat_tab.dart';
import 'tabs/admin_hardware_tab.dart';
import '../widgets/admin_dashboard_skeleton.dart';

import '../widgets/admin_analytics_card.dart';
import '../widgets/high_risk_residents_card.dart';
import '../widgets/admin_metric_card.dart';
import '../widgets/admin_recent_activity.dart';
import '../../../core/widgets/sync_status_indicator.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // SESSION SECURITY
  Timer? _inactivityTimer;
  static const int _timeoutSeconds = 120;

  // SYSTEM STATUS
  String _networkStatus = "Checking...";
  Color _networkColor = Colors.grey;
  bool _isInitializing = true;

  // TAB STATE
  int _selectedIndex = 0;

  Future<void> _initSystem() async {
    final authRepo = context.read<IAuthRepository>();
    final historyRepo = context.read<IHistoryRepository>();
    final adminRepo = context.read<AdminRepository>();

    // 1. Parallel Load Local Data (Instant)
    await Future.wait([
      adminRepo.init(),
      authRepo.refreshUsers(),
      historyRepo.loadAllHistory(),
    ]);

    // 2. Start Cloud Sync in background
    final syncFuture = SyncService().forceDownSyncAndRefresh(authRepo, historyRepo);

    // If local data is empty, we MUST wait for the sync to complete
    if (authRepo.users.isEmpty || historyRepo.records.isEmpty) {
      debugPrint("🛰️ Dashboard: Local DB empty, waiting for initial sync...");
      await syncFuture;
    } else {
      debugPrint("🚀 Dashboard: Local data found, finishing init immediately.");
      // Fire and forget the sync in background
      unawaited(syncFuture);
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  // SYNC STREAM SUBSCRIPTIONS
  StreamSubscription? _residentSyncSub;
  StreamSubscription? _vitalSyncSub;
  StreamSubscription? _alertSyncSub;
  StreamSubscription? _announcementSyncSub;

  @override
  void initState() {
    super.initState();
    _startInactivityTimer();
    _checkSystemHealth();
    
    // Use postFrameCallback to avoid "setState() called during build" error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSystem();
    });

    _setupSyncListeners();
  }

  void _setupSyncListeners() {
    final bus = SyncEventBus.instance;

    // 1. Resident Changes
    _residentSyncSub = bus.residentStream.listen((_) {
      if (mounted) {
        debugPrint("📡 Dashboard: Resident data synced, refreshing UI.");
        context.read<IAuthRepository>().refreshUsers();
      }
    });

    // 2. New Vitals (Live Notifications)
    _vitalSyncSub = bus.vitalsStream.listen((_) {
      debugPrint("🔄 Dashboard: Vitals change detected.");
      if (mounted) {
        context.read<IHistoryRepository>().loadAllHistory();
      }
    });

    // 3. New Alerts (Snackbars)
    _alertSyncSub = bus.newAlertStream.listen((data) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("⚠️ ALERT: ${data['message'] ?? 'New system alert'}"),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ));
      }
    });

    // 4. New Announcements (Snackbars)
    _announcementSyncSub = bus.newAnnouncementStream.listen((data) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("📢 ANNOUNCEMENT: ${data['title'] ?? 'New update'}"),
          backgroundColor: AppColors.brandDark,
          duration: const Duration(seconds: 5),
        ));
      }
    });
  }

  // REPLACED: _setupRealtimeStreams is now handled centrally by SyncService.

  @override
  void dispose() {
    _residentSyncSub?.cancel();
    _vitalSyncSub?.cancel();
    _alertSyncSub?.cancel();
    _announcementSyncSub?.cancel();
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: _timeoutSeconds), () {
      if (mounted) {
        context.go(AppRoutes.adminLogin);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Session expired due to inactivity."),
            backgroundColor: Colors.orange));
      }
    });
  }

  void _resetInactivityTimer() {
    _startInactivityTimer();
  }

  Future<void> _handleManualRefresh() async {
    if (mounted) {
      setState(() {
        _isInitializing = true;
      });
    }

    try {
      final authRepo = context.read<IAuthRepository>();
      final historyRepo = context.read<IHistoryRepository>();

      // 1. Check Connectivity First
      await _checkSystemHealth();

      // 2. Trigger Full Sync and local refresh
      await SyncService().forceDownSyncAndRefresh(authRepo, historyRepo);

      // 3. Small settle delay for UX
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Refresh failed: $e"),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
      
      // Show success message AFTER UI has returned to normal state
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "System connectivity and data refreshed successfully.",
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.brandGreen,
          behavior: SnackBarBehavior.floating,
          width: 400,
        ));
      }
    }
  }

  Future<void> _checkSystemHealth() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        if (connectivityResult == ConnectivityResult.none) {
          _networkStatus = "Offline";
          _networkColor = Colors.orange;
        } else {
          _networkStatus = "Online";
          _networkColor = AppColors.brandGreen;
        }
      });
    }
  }

  // --- ACTIONS & DIALOGS (Kept from previous version) ---
  // ... (Code for _showInputSheet, _showConfigDialog, _verifyAdminAccess, _exportToCSV, _clearDatabase remains valid logic)

  // Re-pasting _showInputSheet and others for completeness since we are replacing the whole file structure.
  void _showInputSheet({
    required String title,
    required List<Widget> fields,
    required VoidCallback onSave,
    required TextEditingController activeController,
    KeyboardType keyboardType = KeyboardType.text,
    int? maxLength,
    String saveLabel = "SAVE CHANGES",
    Color saveColor = AppColors.brandGreen,
  }) {
    // Use AppEnvironment to determine if we should show virtual keyboard
    final bool showVirtualKeyboard = AppEnvironment().shouldShowVirtualKeyboard;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (context, setSheetState) {
        return Container(
          height: !showVirtualKeyboard
              ? MediaQuery.of(context).size.height * 0.6 // Shorter on desktop
              : MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandDark)),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(children: fields),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(backgroundColor: saveColor),
                  child: Text(saveLabel,
                      style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              if (showVirtualKeyboard) ...[
                const SizedBox(height: 24),
                SizedBox(
                  height: 350,
                  child: VirtualKeyboard(
                    controller: activeController,
                    type: keyboardType,
                    maxLength: maxLength,
                    onSubmit: () {},
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTapField(String label, TextEditingController controller,
      ValueNotifier<TextEditingController> notifier, FocusNode focusNode) {
    // Use AppEnvironment to determine input behavior
    final bool showVirtualKeyboard = AppEnvironment().shouldShowVirtualKeyboard;

    return ValueListenableBuilder<TextEditingController>(
        valueListenable: notifier,
        builder: (context, active, _) {
          final isFocused = active == controller;
          return TextField(
            controller: controller,
            focusNode: focusNode,
            readOnly: showVirtualKeyboard, // Direct input for desktop!
            onTap: () {
              notifier.value = controller;
              if (!showVirtualKeyboard) {
                focusNode.requestFocus();
              }
            },
            decoration: InputDecoration(
              labelText: label,
              filled: true,
              fillColor: isFocused
                  ? AppColors.brandGreen.withValues(alpha: 0.1)
                  : Colors.grey[50],
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: const OutlineInputBorder(
                  borderSide:
                      BorderSide(color: AppColors.brandGreen, width: 2)),
            ),
          );
        });
  }

  void _showConfigDialog() async {
    if (!await _verifyAdminAccess()) return;
    if (!mounted) return;

    final ipController = TextEditingController(text: ConfigService().serverIp);
    final activeCtrlNotifier =
        ValueNotifier<TextEditingController>(ipController);
    final ipFocusNode = FocusNode();

    _showInputSheet(
      title: "System Configuration",
      activeController: ipController,
      fields: [
        _buildTapField(
            "Sync Server URL", ipController, activeCtrlNotifier, ipFocusNode),
      ],
      onSave: () async {
        await ConfigService().updateSettings(
          ip: ipController.text,
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Configuration Saved."),
              backgroundColor: AppColors.brandGreen));
        }
      },
    );
  }

  Future<bool> _verifyAdminAccess() async {
    final pinController = TextEditingController();
    final pinFocusNode = FocusNode();
    final completer = Completer<bool>();
    final bool showVirtualKeyboard = AppEnvironment().shouldShowVirtualKeyboard;

    _showInputSheet(
      title: "Security Check",
      activeController: pinController,
      keyboardType: KeyboardType.numeric,
      maxLength: 6,
      saveLabel: "VERIFY PIN",
      saveColor: AppColors.brandDark,
      fields: [
        const Text("Enter Admin PIN to proceed.",
            style: TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 32),
        TextField(
          controller: pinController,
          focusNode: pinFocusNode,
          textAlign: TextAlign.center,
          readOnly: showVirtualKeyboard, // Desktop can type PIN directly!
          obscureText: true,
          style: const TextStyle(
              fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
              hintText: "******", border: OutlineInputBorder()),
          onTap: () {
            if (!showVirtualKeyboard) {
              pinFocusNode.requestFocus();
            }
          },
        ),
      ],
      onSave: () {
        if (pinController.text == "123456") {
          Navigator.pop(context);
          completer.complete(true);
        } else {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Invalid PIN."), backgroundColor: Colors.red));
          completer.complete(false);
        }
      },
    );
    return completer.future;
  }


  Future<void> _clearDatabase() async {
    if (AdminSecurityService().currentRole != AdminRole.superAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Action blocked: Require Super Admin privileges."),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (!await _verifyAdminAccess()) return;
    if (!mounted) return;

    await context.read<IHistoryRepository>().clearHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Database cleared."),
        backgroundColor: AppColors.brandGreen));
    context.read<IHistoryRepository>().loadAllHistory();
  }

  // --- RESPONSIVE BUILD ---
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _resetInactivityTimer,
      onPanDown: (_) => _resetInactivityTimer(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Breakpoint for Mobile vs Desktop
          bool isDesktop = constraints.maxWidth > 900;

          if (_isInitializing) {
            return const AdminDashboardSkeleton();
          }

          if (isDesktop) {
            return _buildDesktopLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  // 1. DESKTOP LAYOUT (With Sidebar)
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            color: AppColors.brandDark,
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.admin_panel_settings,
                    color: Colors.white, size: 64),
                const SizedBox(height: 16),
                Text(AdminSecurityService().activeStaff?.fullName ?? "BHW ADMIN",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                if (AdminSecurityService().activeStaff != null)
                  Text(AdminSecurityService().activeStaff!.role.toUpperCase(),
                    style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppEnvironment().isKiosk
                        ? AppColors.brandGreen.withValues(alpha: 0.2)
                        : Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppEnvironment().isKiosk
                          ? AppColors.brandGreen
                          : Colors.blue,
                    ),
                  ),
                  child: Text(
                    AppEnvironment().isKiosk ? "KIOSK MODE" : "DESKTOP MODE",
                    style: TextStyle(
                      color: AppEnvironment().isKiosk
                          ? AppColors.brandGreen
                          : Colors.blue[300],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // HMIS Modules
                        _buildSidebarItem("Overview", Icons.dashboard, 0),
                        _buildSidebarItem(
                            "Triage: Attention", Icons.priority_high_rounded, 1),
                        _buildSidebarItem(
                            "Validation", Icons.check_circle_outline, 2),
                        _buildSidebarItem(
                            "Broadcast Center", Icons.campaign, 3),
                        _buildSidebarItem(
                            "Resident Support", Icons.chat_bubble_outline, 4),
                        _buildSidebarItem("Schedules", Icons.calendar_month, 5),
                        _buildSidebarItem("Reports", Icons.receipt_long, 6),
                        if (AppEnvironment().hasHardwareAccess)
                          _buildSidebarItem("Hardware Control",
                              Icons.settings_input_component, 7),

                        const Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 24.0),
                          child: Divider(color: Colors.white24),
                        ),

                        // System Modules
                        _buildNavigationItem("Users Directory", Icons.people,
                            onTap: () => context.push(AppRoutes.adminUsers)),
                        _buildNavigationItem("Security Logs", Icons.security,
                            onTap: () => context.push(AppRoutes.adminLogs)),
                        _buildNavigationItem("System Info", Icons.info,
                            onTap: () =>
                                context.push(AppRoutes.adminSystemInfo)),
                        _buildNavigationItem("System Logs", Icons.terminal,
                            onTap: () =>
                                context.push(AppRoutes.adminDiagnostics)),
                        _buildNavigationItem("Admin Settings", Icons.settings,
                            onTap: () => context.push(AppRoutes.adminSettings)),
                      ],
                    ),
                  ),
                ),
                _buildNavigationItem("Logout", Icons.logout,
                    color: Colors.redAccent, onTap: () async {
                  await context.read<IAuthRepository>().logout();
                  if (mounted) {
                    // Kiosk Admin goes back to Resident Login, Desktop Admin stays in Admin Login
                    if (AppEnvironment().isKiosk) {
                      context.go(AppRoutes.login);
                    } else {
                      context.go(AppRoutes.adminLogin);
                    }
                  }
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Text(_getAppBarTitle(),
                    style: const TextStyle(color: Colors.black)),
                backgroundColor: Colors.white,
                elevation: 0,
                actions: [
                  const RepaintBoundary(child: SyncStatusIndicator()),
                  const SizedBox(width: 8),
                  IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.black),
                      onPressed: _handleManualRefresh),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.black),
                    onSelected: (value) {
                      if (value == 'config') _showConfigDialog();
                      if (value == 'clear') _clearDatabase();
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'config',
                        child: Text('System Config'),
                      ),
                      if (AdminSecurityService().currentRole ==
                          AdminRole.superAdmin)
                        const PopupMenuItem<String>(
                          value: 'clear',
                          child: Text('Wipe Database',
                              style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              body: _buildBodyContent(isMobile: false),
            ),
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return "Dashboard Overview";
      case 1:
        return "Triage: Immediate Attention";
      case 2:
        return "Validation & Follow-up";
      case 3:
        return "Broadcast & Alert Center";
      case 4:
        return "Resident Support Center";
      case 5:
        return "Health Activity Scheduling";
      case 6:
        return "Barangay Health Reports";
      case 7:
        return "Hardware Diagnostic & Calibration";
      default:
        return "BHW Admin Suite";
    }
  }

  Widget _buildBodyContent({required bool isMobile}) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardBody(isMobile: isMobile);
      case 1:
        return const AdminTriageTab();
      case 2:
        return const AdminValidationTab();
      case 3:
        return const AdminBroadcastTab();
      case 4:
        return const AdminChatTab();
      case 5:
        return const AdminSchedulingTab();
      case 6:
        return const AdminReportsTab();
      case 7:
        return const AdminHardwareTab();
      default:
        return _buildDashboardBody(isMobile: isMobile);
    }
  }

  Widget _buildSidebarItem(String title, IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: isSelected
            ? AppColors.brandGreen
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedIndex = index),
          hoverColor: AppColors.brandGreen.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? Colors.white : Colors.grey[400]),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[400],
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14)),
                ),
                if (index == 4) // Inbox
                  Consumer<IChatRepository>(
                    builder: (context, chatRepo, _) {
                      final count = chatRepo.getUnreadCount(null);
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        child: Text("$count",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                if (index == 1) // Triage
                  Consumer2<IHistoryRepository, IAuthRepository>(
                    builder: (context, historyRepo, authRepo, _) {
                      final count = historyRepo.records.where((r) {
                        final users = authRepo.users.where((u) => u.id == r.userId);
                        if (users.isEmpty) return false;
                        return HealthThresholds.isCritical(users.first, r);
                      }).length;
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: Colors.orange, shape: BoxShape.circle),
                        child: Text("$count",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationItem(String title, IconData icon,
      {required VoidCallback onTap, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          hoverColor: (color ?? AppColors.brandGreen).withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: color ?? Colors.grey[400]),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          color: color ?? Colors.grey[400], fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 2. MOBILE LAYOUT (With Drawer)
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_getAppBarTitle(),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.brandDark,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text("System Admin"),
              accountEmail: Text("Logged In"),
              decoration: BoxDecoration(color: AppColors.brandDark),
              currentAccountPicture: Icon(Icons.admin_panel_settings,
                  size: 48, color: Colors.white),
            ),
            ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text("Overview"),
                onTap: () {
                  setState(() => _selectedIndex = 0);
                  Navigator.pop(context);
                }),
            ListTile(
                leading: const Icon(Icons.priority_high_rounded, color: Colors.orange),
                title: const Text("Triage: Attention"),
                onTap: () {
                  setState(() => _selectedIndex = 1);
                  Navigator.pop(context);
                }),
            ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text("Validation"),
                onTap: () {
                  setState(() => _selectedIndex = 2);
                  Navigator.pop(context);
                }),
            ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Resident Support"),
                    Consumer<IChatRepository>(
                      builder: (context, chatRepo, _) {
                        final count = chatRepo.getUnreadCount(null);
                        if (count == 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: Text("$count", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                  ],
                ),
                onTap: () {
                  setState(() => _selectedIndex = 4);
                  Navigator.pop(context);
                }),
            ListTile(
                leading: const Icon(Icons.campaign),
                title: const Text("Broadcast Center"),
                onTap: () {
                  setState(() => _selectedIndex = 3);
                  Navigator.pop(context);
                }),
            const Divider(),
            ListTile(
                leading: const Icon(Icons.people),
                title: const Text("Resident Database"),
                onTap: () => context.push(AppRoutes.adminUsers)),
            ListTile(
                leading: const Icon(Icons.settings),
                title: const Text("Admin Settings"),
                onTap: () => context.push(AppRoutes.adminSettings)),
            const Divider(),
            ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title:
                    const Text("Logout", style: TextStyle(color: Colors.red)),
                onTap: () {
                  context.read<IAuthRepository>().logout();
                  context.go(AppRoutes.adminLogin);
                }),
          ],
        ),
      ),
      body: _buildBodyContent(isMobile: true),
    );
  }


  Widget _buildDashboardBody({required bool isMobile}) {
    final authRepo = context.watch<IAuthRepository>();
    final historyRepo = context.watch<IHistoryRepository>();
    context.watch<AdminRepository>(); // Watch for threshold changes

    final allUsers = authRepo.users;
    final records = historyRepo.records;

    final todayRecords = records
        .where((r) =>
            r.timestamp.day == DateTime.now().day &&
            r.timestamp.month == DateTime.now().month &&
            r.timestamp.year == DateTime.now().year)
        .toList();

    final alertsCount = records.where((r) {
      final user = allUsers.cast<User?>().firstWhere((u) => u?.id == r.userId, orElse: () => null);
      if (user == null) return false;
      return HealthThresholds.isCritical(user, r);
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI HEADER ROW
          isMobile
              ? Column(
                  children: [
                    Row(children: [
                      AdminMetricCard(title: "Total Residents", value: "${allUsers.length}",
                          icon: Icons.people, color: Colors.blue, isMobile: isMobile, onAction: (val) => _handleCardAction(val, "Total Residents")),
                      const SizedBox(width: 16),
                      AdminMetricCard(title: "Checks Today", value: "${todayRecords.length}",
                          icon: Icons.today, color: AppColors.brandGreen, isMobile: isMobile, onAction: (val) => _handleCardAction(val, "Checks Today")),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      AdminMetricCard(title: "Alerts", value: "$alertsCount",
                          icon: Icons.warning_amber_rounded, color: Colors.orange, isMobile: isMobile, onAction: (val) => _handleCardAction(val, "Alerts")),
                      const SizedBox(width: 16),
                      AdminMetricCard(title: "Status", value: _networkStatus, icon: Icons.wifi,
                          color: _networkColor, isMobile: isMobile, onAction: (val) => _handleCardAction(val, "Status")),
                    ]),
                  ],
                )
              : Row(
                  children: [
                    AdminMetricCard(title: "Total Residents", value: "${allUsers.length}",
                        icon: Icons.people, color: Colors.blue, isMobile: isMobile, onAction: (val) => _handleCardAction(val, "Total Residents")),
                    const SizedBox(width: 16),
                    AdminMetricCard(title: "Checks Today", value: "${todayRecords.length}",
                        icon: Icons.today, color: AppColors.brandGreen, isMobile: isMobile, onAction: (val) => _handleCardAction(val, "Checks Today")),
                    const SizedBox(width: 16),
                    AdminMetricCard(title: "Alerts", value: "$alertsCount",
                        icon: Icons.warning_amber_rounded, color: Colors.orange, isMobile: isMobile, onAction: (val) => _handleCardAction(val, "Alerts")),
                    const SizedBox(width: 16),
                    AdminMetricCard(title: "Status", value: _networkStatus, icon: Icons.wifi,
                        color: _networkColor, isMobile: isMobile, onAction: (val) => _handleCardAction(val, "Status")),
                  ],
                ),
          const SizedBox(height: 32),

          // MAIN CONTENT AREA
          if (isMobile) ...[
            AdminAnalyticsCard(records: records, users: allUsers),
            const SizedBox(height: 32),
            HighRiskResidentsCard(users: allUsers, records: records),
            const SizedBox(height: 32),
            AdminRecentActivity(records: records),
          ] else ...[
            // DESKTOP: Balanced Two-Column Layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side: Trends and High Level Analytics
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      AdminAnalyticsCard(records: records, users: allUsers),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // Right Side: Sidebar Triage and Live Activity
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      RepaintBoundary(child: HighRiskResidentsCard(users: allUsers, records: records)),
                      const SizedBox(height: 32),
                      RepaintBoundary(child: AdminRecentActivity(records: records)),
                    ],
                  ),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }

  void _handleCardAction(String val, String title) {
    switch (val) {
      case 'users':
        context.push(AppRoutes.adminUsers);
        break;
      case 'validation':
        setState(() => _selectedIndex = 2);
        break;
      case 'alerts':
        setState(() => _selectedIndex = 1);
        break;
      case 'refresh':
        _handleManualRefresh();
        break;
    }
  }

}
