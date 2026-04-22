import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/routes.dart';
import '../../../core/widgets/logo_glow.dart';
import '../../../core/widgets/flow_animated_button.dart';
import '../../../core/widgets/virtual_keyboard.dart';
import '../domain/i_auth_repository.dart';
import '../../../core/domain/i_system_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/mixins/virtual_keyboard_mixin.dart';
import '../../../core/services/system/app_environment.dart';
import '../../../core/services/system/weather_service.dart';
import '../../../core/services/database/sync_service.dart';
import '../../../core/services/database/connection_manager.dart';
import '../../../core/services/hardware/sensor_manager.dart';
import '../../../core/services/hardware/sensor_service_interface.dart';

enum LoginView { selection, resident, visitor }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with VirtualKeyboardMixin {
  bool get isKiosk => AppEnvironment().shouldShowVirtualKeyboard;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _visitorNameController = TextEditingController();
  
  // We use UniqueKeys for the view containers to ensure clean transitions
  // and view-specific GlobalKeys for field positioning.
  late GlobalKey _usernameFieldKey;
  late GlobalKey _phoneFieldKey;
  late GlobalKey _visitorNameFieldKey;

  bool _isPasswordVisible = false;
  bool _isRightPanelExpanded = false;
  WeatherData? _currentWeather;
  LoginView _currentView = LoginView.selection;
  StreamSubscription? _fingerprintSub;
  String? _fingerprintStatus;

  // --- Admin Hold Logic ---
  Timer? _adminHoldTimer;
  double _adminHoldScale = 1.0;
  final int _holdDurationSeconds = 10;

  @override
  void initState() {
    super.initState();
    _usernameFieldKey = GlobalKey();
    _phoneFieldKey = GlobalKey();
    _visitorNameFieldKey = GlobalKey();
    _loadInitialData();
  }

  @override
  void dispose() {
    _fingerprintSub?.cancel();
    _usernameController.dispose();
    _phoneController.dispose();
    _visitorNameController.dispose();
    super.dispose();
  }

  void _switchView(LoginView view) {
    // 1. Clean up old view state
    _fingerprintSub?.cancel();
    _fingerprintStatus = null;

    setState(() {
      _currentView = view;
      // Re-generate keys for the new view to prevent GlobalKey collisions during animation
      _usernameFieldKey = GlobalKey();
      _phoneFieldKey = GlobalKey();
      _visitorNameFieldKey = GlobalKey();
    });

    // 2. Specialized view initialization
    if (view == LoginView.resident) {
      _startFingerprintListen();
    }
  }

  void _startFingerprintListen() {
    _fingerprintSub?.cancel();
    _fingerprintSub = SensorManager().allDataStream.listen((event) {
      if (event.type == SensorType.fingerprint && event.data is Map) {
        final match = event.data as Map;
        if (match['type'] == 'fingerprint_match') {
          final fingerId = match['id'];
          _handleFingerprintLogin(fingerId);
        }
      }
    });
  }

  Future<void> _handleFingerprintLogin(int fingerId) async {
    setState(() => _fingerprintStatus = "Processing Fingerprint...");
    final result = await context.read<IAuthRepository>().loginWithFingerprint(fingerId);
    
    if (result == null) {
      if (mounted) context.go(AppRoutes.home);
    } else {
      if (mounted) {
        setState(() => _fingerprintStatus = result);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _fingerprintStatus = null);
        });
      }
    }
  }

  Future<void> _loadInitialData() async {
    final weather = await WeatherService().fetchCurrentWeather();
    if (mounted) setState(() => _currentWeather = weather);
  }

  void _showAdminExitDialog() {
    final passwordController = TextEditingController();
    final env = AppEnvironment();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final bool keyboardActive = isKeyboardVisible;

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Align(
                alignment: keyboardActive ? const Alignment(0, -1.0) : Alignment.center,
                child: Container(
                  constraints: BoxConstraints(maxWidth: keyboardActive ? 380 : 440),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3E9),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.security_rounded, color: AppColors.brandGreen, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            env.isKiosk ? "System Exit" : "Admin Exit",
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.brandDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Admin Password",
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.brandGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        onTap: () {
                          if (env.isKiosk) {
                            showKeyboard(passwordController, null, type: KeyboardType.text);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              if (passwordController.text == env.adminExitPassword) {
                                Navigator.pop(dialogContext); // Close dialog first
                                if (env.isKiosk) {
                                  exit(0);
                                } else {
                                  context.go(AppRoutes.adminDashboard);
                                }
                              } else {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(content: Text("Incorrect password"), backgroundColor: Colors.red),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(env.isKiosk ? "Exit App" : "Proceed"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _startAdminHold() {
    _adminHoldTimer?.cancel();
    setState(() => _adminHoldScale = 1.1);
    _adminHoldTimer = Timer(Duration(seconds: _holdDurationSeconds), () {
      if (mounted) {
        setState(() => _adminHoldScale = 1.0);
        _showAdminExitDialog();
      }
    });
  }

  void _stopAdminHold() {
    _adminHoldTimer?.cancel();
    _adminHoldTimer = null;
    if (mounted) setState(() => _adminHoldScale = 1.0);
  }

  Future<void> _handleLogin() async {
    final success = await context.read<IAuthRepository>().login(
          _usernameController.text.trim(),
          _phoneController.text.trim(),
        );

    if (success == null) {
      if (!mounted) return;
      context.go(AppRoutes.home);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success), backgroundColor: Colors.red));
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: AppColors.brandGreen),
            const SizedBox(width: 12),
            Text("Need Assistance?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("To access your records, please provide:"),
            const SizedBox(height: 12),
            _helpItem(Icons.account_circle_outlined, "Username: hYYXXXX (e.g. h260001)"),
            _helpItem(Icons.person_search_outlined, "Legacy Login: Type your Full Name"),
            _helpItem(Icons.phone_android_rounded, "Password: Your Phone Number"),
            const SizedBox(height: 16),
            const Text("If you forgot your details, please visit the Barangay Health Worker desk.", 
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Got it"))
        ],
      ),
    );
  }

  Widget _helpItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.brandGreen),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLoading = context.watch<IAuthRepository>().isLoading;

    return Scaffold(
      body: Stack(
        children: [
          // Dynamic Background
          Container(decoration: const BoxDecoration(color: Color(0xFFF8FAFC))),
          Positioned(
            top: -150,
            left: -150,
            child: _buildMeshCircle(800, AppColors.brandGreen.withValues(alpha: 0.08)),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: _buildMeshCircle(500, AppColors.brandGreen.withValues(alpha: 0.04)),
          ),
          
          SafeArea(
            child: Row(
              children: [
                // MAIN LOGIN AREA
                Expanded(
                  child: Column(
                    children: [
                      _buildTopHeader(l10n),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Informative Sidebars (Left Side)
                            Positioned(
                              left: 40, 
                              bottom: 60, 
                              child: _buildInfoCard(Icons.emergency_rounded, "Hotline", "911 / 143", Colors.redAccent)
                            ),
                            
                            Positioned(
                              left: 40, 
                              top: 20, 
                              child: _buildInfoCard(
                                _currentWeather?.condition.contains("Rain") ?? false ? Icons.umbrella_rounded : Icons.wb_sunny_rounded, 
                                "Weather", 
                                "${_currentWeather?.temperature.toStringAsFixed(0) ?? '29'}°C ${_currentWeather?.condition ?? 'Clear'}", 
                                Colors.orangeAccent
                              )
                            ),

                            // NEW: Hardware Status
                            Positioned(
                              left: 40,
                              top: 110,
                              child: StreamBuilder<Map<SensorType, bool>>(
                                stream: SensorManager().physicalStatusStream,
                                builder: (context, snapshot) {
                                  final status = snapshot.data ?? {};
                                  final isHubConnected = status[SensorType.weight] ?? false;
                                  
                                  return _buildInfoCard(
                                    isHubConnected ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                                    "Hardware",
                                    isHubConnected ? "Ready & Calibrated" : "Check Sensors",
                                    isHubConnected ? AppColors.brandGreen : Colors.grey,
                                  );
                                },
                              ),
                            ),

                            Positioned(
                              left: 40, 
                              bottom: 150, 
                              child: StreamBuilder<DateTime?>(
                                stream: SyncService().lastSyncStream,
                                builder: (context, snapshot) {
                                  final lastSync = snapshot.data ?? SyncService().lastSyncTime;
                                  final isOnline = ConnectionManager().currentStatus == ConnectionStatus.online;
                                  final statusText = isOnline 
                                    ? (lastSync != null ? "Last Sync: ${DateFormat('HH:mm').format(lastSync)}" : "Syncing...")
                                    : "Offline Mode";
                                  
                                  return _buildInfoCard(
                                    Icons.sync_rounded, 
                                    "System", 
                                    statusText, 
                                    isOnline ? Colors.blueAccent : Colors.grey
                                  );
                                }
                              )
                            ),
                            
                            Center(
                              child: SingleChildScrollView(
                                controller: scrollController,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onLongPressStart: (_) => _startAdminHold(),
                                      onLongPressEnd: (_) => _stopAdminHold(),
                                      onLongPressCancel: () => _stopAdminHold(),
                                      child: AnimatedScale(
                                        scale: _adminHoldScale,
                                        duration: const Duration(milliseconds: 200),
                                        child: Column(
                                          children: [
                                            const LogoGlow(
                                              size: 130,
                                              animate: false,
                                              child: Icon(Icons.medical_services_rounded, size: 60, color: AppColors.brandGreen),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              l10n.welcome,
                                              style: GoogleFonts.outfit(
                                                  fontSize: 42,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.brandDark,
                                                  letterSpacing: -1.0),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 600),
                                      switchInCurve: Curves.easeOutBack,
                                      switchOutCurve: Curves.easeInQuad,
                                      transitionBuilder: (Widget child, Animation<double> animation) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0.05, 0),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: _buildCurrentView(l10n, isLoading),
                                    ),
                                    // Custom Spacer to allow scrolling above the virtual keyboard
                                    if (isKeyboardVisible) 
                                      const SizedBox(height: 220),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildVersionFooter(),
                    ],
                  ),
                ),
                
                // RIGHT SIDE ANNOUNCEMENT PANEL
                _buildRightPanel(l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.barangayHeader, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.brandDark)),
              Text("Kanluran Health Monitoring Facility", style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
            ],
          ),
          IconButton(onPressed: _showHelpDialog, icon: const Icon(Icons.help_outline_rounded, size: 30, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brandDark.withValues(alpha: 0.5),
                          letterSpacing: 1.0)),
                  Text(value,
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandDark)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel(AppLocalizations l10n) {
    final systemRepo = context.read<ISystemRepository>();

    return GestureDetector(
      onTap: () => setState(() => _isRightPanelExpanded = !_isRightPanelExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
        width: _isRightPanelExpanded ? 380 : 80,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _isRightPanelExpanded ? 0.95 : 0.8),
          border: const Border(left: BorderSide(color: Colors.white, width: 2)),
          boxShadow: [
            if (_isRightPanelExpanded) 
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 40)
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            AnimatedRotation(
              turns: _isRightPanelExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: const Icon(Icons.campaign_rounded, color: AppColors.brandGreen, size: 30),
            ),
            if (!_isRightPanelExpanded)
              const Expanded(
                child: RotatedBox(
                  quarterTurns: 1, 
                  child: Text("WHAT'S NEW", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 4, color: AppColors.brandGreen))
                )
              ),
            
            if (_isRightPanelExpanded) ...[
              Expanded(
                child: ClipRect(
                  child: OverflowBox(
                    minWidth: 380,
                    maxWidth: 380,
                    alignment: Alignment.topLeft,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.whatsNew,
                                  style: GoogleFonts.outfit(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.brandGreen),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.close_rounded,
                                  color: Colors.grey, size: 20),
                            ],
                          ),
                        ),
                        const Divider(indent: 20, endIndent: 20),
                        Expanded(
                          child: FutureBuilder<List<Map<String, dynamic>>>(
                            future: systemRepo.fetchAnnouncements(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No current announcements.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))));
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  final item = snapshot.data![index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50, 
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.grey.shade100),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['title'] ?? 'Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.brandDark)),
                                        const SizedBox(height: 8),
                                        Text(item['content'] ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF5A5A5A), height: 1.4)),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildVersionFooter() {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("v1.2.9+pht", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          Text("Official San Agustin Kiosk Portal", style: TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildCurrentView(AppLocalizations l10n, bool isLoading) {
    switch (_currentView) {
      case LoginView.resident:
        return KeyedSubtree(
          key: ValueKey('resident_${_usernameFieldKey.hashCode}'),
          child: _buildResidentView(l10n, isLoading),
        );
      case LoginView.visitor:
        return KeyedSubtree(
          key: ValueKey('visitor_${_visitorNameFieldKey.hashCode}'),
          child: _buildVisitorView(l10n, isLoading),
        );
      default:
        return _buildSelectionView(l10n);
    }
  }

  Widget _buildSelectionView(AppLocalizations l10n) {
    return Column(
      key: const ValueKey('selection'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSelectionCard(
              l10n.iamResident,
              l10n.residentDesc,
              Icons.home_work_rounded,
              AppColors.brandGreen,
              () => _switchView(LoginView.resident),
            ),
            const SizedBox(width: 32),
            _buildSelectionCard(
              l10n.iamVisitor,
              l10n.visitorDesc,
              Icons.person_pin_circle_rounded,
              Colors.blueAccent,
              () => _switchView(LoginView.visitor),
            ),
          ],
        ),
        const SizedBox(height: 40),
        TextButton(
          onPressed: () => context.go(AppRoutes.register),
          child: Text(l10n.noAccountCreate, 
            style: const TextStyle(color: AppColors.brandGreen, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildSelectionCard(String title, String desc, IconData icon, Color color, VoidCallback onTap) {
    return FlowAnimatedButton(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 380,
          height: 380,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 64, color: color),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brandDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResidentView(AppLocalizations l10n, bool isLoading) {
    return Column(
      key: const ValueKey('resident'),
      children: [
        _buildLoginCard(l10n, isLoading),
        const SizedBox(height: 24),
        _buildBackButton(),
      ],
    );
  }

  Widget _buildVisitorView(AppLocalizations l10n, bool isLoading) {
    return Column(
      key: const ValueKey('visitor'),
      children: [
        _buildVisitorCard(l10n, isLoading),
        const SizedBox(height: 24),
        _buildBackButton(),
      ],
    );
  }

  Widget _buildBackButton() {
    return TextButton.icon(
      onPressed: () => _switchView(LoginView.selection),
      icon: const Icon(Icons.arrow_back_rounded, color: Colors.grey),
      label: const Text("Go Back", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildVisitorCard(AppLocalizations l10n, bool isLoading) {
    return Container(
      width: 700,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 40, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.enterFullName.toUpperCase(), 
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.blueAccent, fontSize: 14, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          TextField(
            key: _visitorNameFieldKey,
            controller: _visitorNameController,
            readOnly: isKiosk,
            onTap: () => isKiosk ? showKeyboard(_visitorNameController, _visitorNameFieldKey) : null,
            style: TextStyle(
              fontSize: 22, 
              fontWeight: FontWeight.bold,
              color: AppColors.brandDark.withValues(alpha: 0.7),
            ),
            decoration: _inputDecoration(l10n.fullName, Icons.person_outline_rounded),
          ),
          const SizedBox(height: 48),
          if (isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          else
            FlowAnimatedButton(
              child: ElevatedButton(
                onPressed: _handleVisitorLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 80),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                ),
                child: Text(l10n.loginBtn.toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
        ],
      ),
    );
  }



  Future<void> _handleVisitorLogin() async {
    final name = _visitorNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your full name."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isPasswordVisible = false); // reuse for loading if needed, but better to have isLoading
    final authRepo = context.read<IAuthRepository>();
    await authRepo.loginAsVisitor(name);
    
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  Widget _buildMeshCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)])),
    );
  }

  Widget _buildLoginCard(AppLocalizations l10n, bool isLoading) {
    return Container(
      width: 700,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 40, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.residentLogin.toUpperCase(), 
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.brandGreen, fontSize: 14, letterSpacing: 1.2)),
              if (_fingerprintStatus != null)
                Text(_fingerprintStatus!, style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))
              else
                const Row(
                  children: [
                    Icon(Icons.fingerprint_rounded, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text("BIOMETRIC READY", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w900)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: _usernameFieldKey,
            controller: _usernameController,
            readOnly: isKiosk,
            onTap: () => isKiosk ? showKeyboard(_usernameController, _usernameFieldKey) : null,
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold,
              color: AppColors.brandDark.withValues(alpha: 0.75),
            ),
            decoration: _inputDecoration("hYYXXXX", Icons.account_circle_outlined),
          ),
          const SizedBox(height: 24),
          Text(l10n.enterPassword, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.brandGreen, fontSize: 14, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          TextField(
            key: _phoneFieldKey,
            controller: _phoneController,
            obscureText: !_isPasswordVisible,
            readOnly: isKiosk,
            onTap: () => isKiosk ? showKeyboard(_phoneController, _phoneFieldKey, type: KeyboardType.numeric, maxLength: 11) : null,
            style: TextStyle(
              fontSize: 22, 
              fontWeight: FontWeight.bold, 
              letterSpacing: 4,
              color: AppColors.brandDark.withValues(alpha: 0.7),
            ),
            decoration: _inputDecoration(l10n.phoneNumber, Icons.lock_person_rounded).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: AppColors.brandGreen),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
          ),
          const SizedBox(height: 40),
          if (isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.brandGreen))
          else
            FlowAnimatedButton(
              child: ElevatedButton(
                onPressed: _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 70),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                ),
                child: Text(l10n.accessRecord.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fingerprint_rounded, color: AppColors.brandGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(l10n.placeFingerToLogin, 
                    style: const TextStyle(color: AppColors.brandGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(
        color: AppColors.brandDark.withValues(alpha: 0.35),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: AppColors.brandGreen.withValues(alpha: 0.6)),
      filled: true,
      fillColor: Colors.grey[100]?.withValues(alpha: 0.8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 20),
    );
  }
}
