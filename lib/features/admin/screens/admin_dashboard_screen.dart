import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';


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
import '../../health_check/models/vital_signs_model.dart';
import '../../../core/services/database/sync_service.dart';
import '../../../core/services/system/sync_event_bus.dart';

// NEW TABS
import 'tabs/admin_validation_tab.dart';
import 'tabs/admin_announcements_tab.dart';
import 'tabs/admin_scheduling_tab.dart';
import 'tabs/admin_alerts_tab.dart';
import 'tabs/admin_reports_tab.dart';
import 'tabs/admin_chat_tab.dart';
import 'tabs/admin_hardware_tab.dart'; // NEW

// NEW WIDGETS
import '../widgets/admin_analytics_card.dart';
import '../widgets/high_risk_patients_card.dart';
import '../widgets/admin_patient_profile_sidebar.dart';

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

  // TAB STATE
  int _selectedIndex = 0;

  // SYNC STREAM SUBSCRIPTIONS
  StreamSubscription? _patientSyncSub;
  StreamSubscription? _vitalSyncSub;
  StreamSubscription? _alertSyncSub;
  StreamSubscription? _announcementSyncSub;

  @override
  void initState() {
    super.initState();
    _startInactivityTimer();
    _checkSystemHealth();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authRepo = context.read<IAuthRepository>();
      final historyRepo = context.read<IHistoryRepository>();

      // Force a manual cloud sweep as soon as the Admin Desktop starts up
      await SyncService().forceDownSyncAndRefresh(authRepo, historyRepo);
    });

    _setupSyncListeners();
  }

  void _setupSyncListeners() {
    final bus = SyncEventBus.instance;

    // 1. Patient Changes
    _patientSyncSub = bus.patientStream.listen((_) {
      if (mounted) {
        debugPrint("🔄 Dashboard: Patient data synced, refreshing UI.");
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
    _patientSyncSub?.cancel();
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

  Future<void> _exportToCSV() async {
    try {
      final historyRepo = context.read<IHistoryRepository>();
      final authRepo = context.read<IAuthRepository>();
      final records = historyRepo.records;

      if (records.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("No records to export."),
            backgroundColor: Colors.orange));
        return;
      }

      List<List<dynamic>> rows = [];
      rows.add([
        "Record ID",
        "Patient Name",
        "Phone Number",
        "Date",
        "Time",
        "Heart Rate",
        "Systolic BP",
        "Diastolic BP",
        "Oxygen",
        "Temperature",
        "BMI",
        "BMI Category"
      ]);

      for (var record in records) {
        final user = authRepo.users.firstWhere((u) => u.id == record.userId,
            orElse: () => User(
                id: '',
                firstName: 'Unknown',
                middleInitial: '',
                lastName: '',
                sitio: '',
                phoneNumber: '',
                pinCode: '123456',
                dateOfBirth: DateTime.now(),
                gender: ''));

        rows.add([
          record.id,
          user.fullName,
          user.phoneNumber,
          "${record.timestamp.year}-${record.timestamp.month.toString().padLeft(2, '0')}-${record.timestamp.day.toString().padLeft(2, '0')}",
          "${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}",
          record.heartRate,
          record.systolicBP,
          record.diastolicBP,
          record.oxygen,
          record.temperature,
          record.bmi ?? '',
          record.bmiCategory ?? ''
        ]);
      }

      String csv = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final String filePath =
          '${directory.path}/kiosk_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final File file = File(filePath);
      await file.writeAsString(csv);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Export saved to: $filePath"),
        backgroundColor: AppColors.brandGreen,
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  void _confirmDeleteUser(User user) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Delete Patient"),
              content: Text(
                  "Are you sure you want to permanently delete ${user.fullName}?"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("CANCEL")),
                TextButton(
                  onPressed: () {
                    context.read<IAuthRepository>().deleteUser(user.id);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Patient deleted."),
                      backgroundColor: Colors.red,
                    ));
                  },
                  child:
                      const Text("DELETE", style: TextStyle(color: Colors.red)),
                ),
              ],
            ));
  }

  final List<String> _allSitios = [
    "Sitio Ayala",
    "Sitio Mahabang Buhangin",
    "Sitio Sampalucan",
    "Sitio Hulo",
    "Sitio Labak",
    "Sitio Macaraigan",
    "Sitio Gabihan",
  ];

  void _editUser(User user) {
    if (!mounted) return;

    final nameController = TextEditingController(text: user.firstName);
    final lastController = TextEditingController(text: user.lastName);
    final miController = TextEditingController(text: user.middleInitial);
    final phoneController = TextEditingController(text: user.phoneNumber);
    String selectedSitio = user.sitio;
    TextEditingController activeCtrl = nameController;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (context, setSheetState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Edit Patient",
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx)),
              ]),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSheetField("First Name", nameController, activeCtrl,
                          (c) => setSheetState(() => activeCtrl = c)),
                      const SizedBox(height: 12),
                      _buildSheetField("Last Name", lastController, activeCtrl,
                          (c) => setSheetState(() => activeCtrl = c)),
                      const SizedBox(height: 12),
                      _buildSheetField(
                          "Middle Initial",
                          miController,
                          activeCtrl,
                          (c) => setSheetState(() => activeCtrl = c),
                          maxLength: 2),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _allSitios.contains(selectedSitio)
                            ? selectedSitio
                            : _allSitios[0],
                        items: _allSitios
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (val) =>
                            setSheetState(() => selectedSitio = val!),
                        decoration: const InputDecoration(
                            labelText: "Sitio", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      _buildSheetField("Phone", phoneController, activeCtrl,
                          (c) => setSheetState(() => activeCtrl = c),
                          type: KeyboardType.numeric, maxLength: 11),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final updatedUser = user.copyWith(
                        firstName: nameController.text,
                        lastName: lastController.text,
                        middleInitial: miController.text,
                        sitio: selectedSitio,
                        phoneNumber: phoneController.text,
                        pinCode: '123456');

                    context.read<IAuthRepository>().updateUser(updatedUser);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("User updated.")));
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandGreen),
                  child: const Text("Save Changes",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSheetField(String label, TextEditingController controller,
      TextEditingController active, Function(TextEditingController) onFocus,
      {KeyboardType type = KeyboardType.text, int? maxLength}) {
    final bool showVirtualKeyboard = AppEnvironment().shouldShowVirtualKeyboard;
    final isFocused = controller == active;
    return TextField(
      controller: controller,
      readOnly: showVirtualKeyboard, // Enable native typing on desktop
      onTap: () {
        onFocus(controller);
        if (!showVirtualKeyboard) {
          // No explicit focus node passed here, but standard tapping works on desktop.
          // We just need to ensure onFocus is called for the UI highlights.
        }
      },
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: isFocused
            ? AppColors.brandGreen.withValues(alpha: 0.1)
            : Colors.grey[50],
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.brandGreen, width: 2)),
        counterText: "",
      ),
    );
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
                const Text("BHW ADMIN",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
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
                            "Validation", Icons.check_circle_outline, 1),
                        _buildSidebarItem("Announcements", Icons.campaign, 2),
                        _buildSidebarItem(
                            "Inbox", Icons.chat_bubble_outline, 3),
                        _buildSidebarItem("Schedules", Icons.calendar_month, 4),
                        _buildSidebarItem(
                            "Alerts", Icons.warning_amber_rounded, 5),
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
                    // Kiosk Admin goes back to Patient Login, Desktop Admin stays in Admin Login
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
                  IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.black),
                      onPressed: () =>
                          context.read<IHistoryRepository>().loadAllHistory()),
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
        return "Validation & Follow-up";
      case 2:
        return "Announcements Management";
      case 3:
        return "Patient Support Inbox";
      case 4:
        return "Health Activity Scheduling";
      case 5:
        return "Official Alert System";
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
        return const AdminValidationTab();
      case 2:
        return const AdminAnnouncementsTab();
      case 3:
        return const AdminChatTab();
      case 4:
        return const AdminSchedulingTab();
      case 5:
        return const AdminAlertsTab();
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
        title: const Text("Admin Mobile",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                title: const Text("Dashboard"),
                onTap: () => Navigator.pop(context)),
            ListTile(
                leading: const Icon(Icons.people),
                title: const Text("User Database"),
                onTap: () => context.push(AppRoutes.adminUsers)),
            ListTile(
                leading: const Icon(Icons.security),
                title: const Text("Security Logs"),
                onTap: () => context.push(AppRoutes.adminLogs)),
            ListTile(
                leading: const Icon(Icons.info),
                title: const Text("System Info"),
                onTap: () => context.push(AppRoutes.adminSystemInfo)),
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
      body: _buildDashboardBody(isMobile: true),
    );
  }

  // --- SHARED DASHBOARD CONTENT ---
  String _searchQuery = "";

  String _getOverallHealthStatus(VitalSigns? record) {
    if (record == null) return "N/A";

    final adminRepo = context.read<AdminRepository>();

    bool isHypertensive =
        record.systolicBP > adminRepo.sysHigh || record.diastolicBP > 90;
    bool isHypotic = record.systolicBP < adminRepo.sysLow;
    bool isHypoxic = record.oxygen < 92;
    bool isFever = record.temperature > 37.8;
    bool isAbnormalHR =
        record.heartRate > adminRepo.hrHigh || record.heartRate < 60;

    if (isHypertensive || isHypotic || isHypoxic || isFever || isAbnormalHR) {
      return "Abnormal";
    }
    return "Normal";
  }

  Widget _buildDashboardBody({required bool isMobile}) {
    final authRepo = context.watch<IAuthRepository>();
    final historyRepo = context.watch<IHistoryRepository>();
    context.watch<AdminRepository>(); // Watch for threshold changes

    final allUsers = authRepo.users;
    final filteredUsers = allUsers
        .where((u) =>
            u.fullName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    final records = historyRepo.records;

    final todayRecords = records
        .where((r) =>
            r.timestamp.day == DateTime.now().day &&
            r.timestamp.month == DateTime.now().month &&
            r.timestamp.year == DateTime.now().year)
        .toList();

    final alertsCount = records
        .where((r) =>
            r.bmiCategory == "Underweight" ||
            r.bmiCategory == "Obese" ||
            r.bmiCategory == "Overweight")
        .length;

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
                      _buildMetricCard("Total Patients", "${allUsers.length}",
                          Icons.people, Colors.blue, isMobile),
                      const SizedBox(width: 16),
                      _buildMetricCard("Checks Today", "${todayRecords.length}",
                          Icons.today, AppColors.brandGreen, isMobile),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      _buildMetricCard("Alerts", "$alertsCount",
                          Icons.warning_amber_rounded, Colors.orange, isMobile),
                      const SizedBox(width: 16),
                      _buildMetricCard("Status", _networkStatus, Icons.wifi,
                          _networkColor, isMobile),
                    ]),
                  ],
                )
              : Row(
                  children: [
                    _buildMetricCard("Total Patients", "${allUsers.length}",
                        Icons.people, Colors.blue, isMobile),
                    const SizedBox(width: 16),
                    _buildMetricCard("Checks Today", "${todayRecords.length}",
                        Icons.today, AppColors.brandGreen, isMobile),
                    const SizedBox(width: 16),
                    _buildMetricCard("Alerts", "$alertsCount",
                        Icons.warning_amber_rounded, Colors.orange, isMobile),
                    const SizedBox(width: 16),
                    _buildMetricCard("Status", _networkStatus, Icons.wifi,
                        _networkColor, isMobile),
                  ],
                ),
          const SizedBox(height: 32),

          // MAIN CONTENT AREA
          if (isMobile) ...[
            AdminAnalyticsCard(records: records),
            const SizedBox(height: 32),
            HighRiskPatientsCard(users: allUsers, records: records),
            const SizedBox(height: 32),
            _buildPatientTable(filteredUsers, records),
            const SizedBox(height: 32),
            _buildRecentActivity(records),
          ] else ...[
            // DESKTOP: Balanced Two-Column Layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side: Trends and Patient Registry
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      AdminAnalyticsCard(records: records),
                      const SizedBox(height: 32),
                      _buildPatientTable(filteredUsers, records),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // Right Side: Sidebar Triage and Live Activity
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      HighRiskPatientsCard(users: allUsers, records: records),
                      const SizedBox(height: 32),
                      _buildRecentActivity(records),
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

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color, bool isMobile) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Column(
          children: [
            // Colored accent strip
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      if (!isMobile)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_horiz,
                              color: Colors.grey.shade400, size: 20),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          itemBuilder: (context) => [
                            if (title == "Total Patients")
                              const PopupMenuItem(
                                  value: 'users',
                                  child: Row(children: [
                                    Icon(Icons.people, size: 18),
                                    SizedBox(width: 8),
                                    Text("View Patient Registry")
                                  ])),
                            if (title == "Checks Today")
                              const PopupMenuItem(
                                  value: 'validation',
                                  child: Row(children: [
                                    Icon(Icons.fact_check, size: 18),
                                    SizedBox(width: 8),
                                    Text("Open Validation Tab")
                                  ])),
                            if (title == "Alerts")
                              const PopupMenuItem(
                                  value: 'alerts',
                                  child: Row(children: [
                                    Icon(Icons.warning_amber, size: 18),
                                    SizedBox(width: 8),
                                    Text("View All Alerts")
                                  ])),
                            if (title == "Status")
                              const PopupMenuItem(
                                  value: 'refresh',
                                  child: Row(children: [
                                    Icon(Icons.refresh, size: 18),
                                    SizedBox(width: 8),
                                    Text("Refresh Connection")
                                  ])),
                          ],
                          onSelected: (val) {
                            switch (val) {
                              case 'users':
                                context.push(AppRoutes.adminUsers);
                                break;
                              case 'validation':
                                setState(() => _selectedIndex = 1);
                                break;
                              case 'alerts':
                                setState(() => _selectedIndex = 4);
                                break;
                              case 'refresh':
                                _checkSystemHealth();
                                break;
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandDark)),
                  const SizedBox(height: 4),
                  Text(title,
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientTable(List<User> users, List<VitalSigns> records) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Patient Registry",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark)),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: "Search patients...",
                            prefixIcon: const Icon(Icons.search, size: 20),
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _exportToCSV,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text("Export"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                    )
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
              dividerThickness: 0.5,
              columns: const [
                DataColumn(
                    label: Text("Name",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Phone / ID",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Last Status",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Account",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text("Actions",
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: users.take(10).map((user) {
                // Find latest record for user
                final userRecords =
                    records.where((r) => r.userId == user.id).toList();
                userRecords.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                final latest =
                    userRecords.isNotEmpty ? userRecords.first : null;

                return DataRow(
                    color: WidgetStateProperty.resolveWith<Color?>(
                        (Set<WidgetState> states) {
                      if (user.isActive == false) return Colors.grey[100];
                      return null;
                    }),
                    cells: [
                      DataCell(Row(children: [
                        CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                AppColors.brandGreen.withValues(alpha: 0.1),
                            child: const Icon(Icons.person,
                                size: 18, color: AppColors.brandGreen)),
                        const SizedBox(width: 12),
                        Text(user.fullName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ])),
                      DataCell(Text(user.phoneNumber,
                          style: const TextStyle(color: Colors.grey))),
                      DataCell(latest != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    _getOverallHealthStatus(latest) == "Normal"
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_getOverallHealthStatus(latest),
                                  style: TextStyle(
                                      color: _getOverallHealthStatus(latest) ==
                                              "Normal"
                                          ? Colors.green[700]
                                          : Colors.red[800],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            )
                          : const Text("No records",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12))),
                      DataCell(Row(
                        children: [
                          Switch(
                            value: user.isActive == true,
                            activeThumbColor: AppColors.brandGreen,
                            onChanged: (val) {
                              context
                                  .read<IAuthRepository>()
                                  .toggleUserStatus(user, val);
                            },
                          ),
                          Text(user.isActive == true ? "Active" : "Archived",
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: user.isActive == true
                                      ? AppColors.brandGreen
                                      : Colors.grey)),
                        ],
                      )),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            icon: const Icon(Icons.analytics,
                                size: 20, color: AppColors.brandDark),
                            onPressed: () =>
                                _showPatientProfile(user, records)),
                        if (AdminSecurityService().currentRole ==
                            AdminRole.superAdmin) ...[
                          IconButton(
                              icon: const Icon(Icons.edit,
                                  size: 20, color: Colors.blue),
                              onPressed: () async {
                                if (await _verifyAdminAccess()) {
                                  _editUser(user);
                                }
                              }),
                          IconButton(
                              icon: const Icon(Icons.delete,
                                  size: 20, color: Colors.red),
                              onPressed: () async {
                                if (await _verifyAdminAccess()) {
                                  _confirmDeleteUser(user);
                                }
                              }),
                        ],
                      ]))
                    ]);
              }).toList(),
            ),
          )
        ],
      ),
    );
  }

  void _showPatientProfile(User user, List<VitalSigns> allRecords) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Profile",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 16,
            child: AdminPatientProfileSidebar(
              patient: user,
              patientRecords:
                  allRecords.where((r) => r.userId == user.id).toList(),
              onMessagePressed: () {
                setState(() => _selectedIndex = 3);
              },
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: const Offset(0, 0))
              .animate(
                  CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  Widget _buildRecentActivity(List<VitalSigns> records) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Recent Activity",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark)),
              Icon(Icons.history, color: Colors.grey)
            ],
          ),
          const SizedBox(height: 24),
          if (records.isEmpty)
            const Text("No recent activity.",
                style: TextStyle(color: Colors.grey))
          else
            ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.length > 10 ? 10 : records.length,
                separatorBuilder: (context, index) => const Divider(height: 32),
                itemBuilder: (context, index) {
                  final record = records[index];
                  // Lookup user for this record
                  final user = context.read<IAuthRepository>().users.firstWhere(
                      (u) => u.id == record.userId,
                      orElse: () => User(
                          id: '',
                          firstName: 'Unknown',
                          middleInitial: '',
                          lastName: '',
                          sitio: '',
                          phoneNumber: '',
                          pinCode: '123456',
                          dateOfBirth: DateTime.now(),
                          gender: ''));

                  return Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.monitor_heart,
                          color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text("${user.firstName} completed a check",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                              "${record.timestamp.day}/${record.timestamp.month}/${record.timestamp.year} at ${record.timestamp.hour}:${record.timestamp.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ])),
                    Text(_getOverallHealthStatus(record),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getOverallHealthStatus(record) == "Normal"
                                ? AppColors.brandGreen
                                : Colors.red))
                  ]);
                })
        ],
      ),
    );
  }
}
