import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/routes.dart';
import '../../../core/services/database/database_helper.dart';
import '../../../core/services/security/admin_security_service.dart';
import '../../../core/services/system/app_environment.dart';
import '../../../core/widgets/virtual_keyboard.dart';
import '../../../core/mixins/virtual_keyboard_mixin.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with VirtualKeyboardMixin {
  final _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  final GlobalKey _pinFieldKey = GlobalKey(); // Added for scroll-to-visible
  bool _isObscured = true;

  // SECURITY STATE
  int _failedAttempts = 0;
  int _remainingSeconds = 0;
  Timer? _lockoutTimer;
  bool _isSetupMode = false;

  static const String _duressPin = "000000";

  @override
  void initState() {
    super.initState();
    _initSecurityState();
  }

  Future<void> _initSecurityState() async {
    // ELITE SECURITY: Check for Developer Hardware Reset Key
    final wasReset = await AdminSecurityService().checkForDeveloperReset();
    if (wasReset && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text("SECURITY: Master PIN has been cleared via Hardware Key."),
        backgroundColor: Colors.blueAccent,
      ));
    }

    final isSetupRequired = await AdminSecurityService().isPinSetupRequired();
    final remaining = await AdminSecurityService().getRemainingLockoutSeconds();

    if (mounted) {
      setState(() {
        _isSetupMode = isSetupRequired;
        _remainingSeconds = remaining;
      });
      if (remaining > 0) _startLockoutTimer();
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining =
          await AdminSecurityService().getRemainingLockoutSeconds();
      if (mounted) {
        setState(() {
          _remainingSeconds = remaining;
          if (remaining <= 0) {
            _failedAttempts = 0;
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _pinController.clear();
    _pinController.dispose();
    _pinFocusNode.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  bool _isSystemLocked() => _remainingSeconds > 0;

  Future<void> _handleLogin() async {
    if (_isSystemLocked()) return;

    final input = _pinController.text;
    if (input.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("PIN must be 6 digits."),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    if (_isSetupMode) {
      await AdminSecurityService().setAdminPin(input);
      if (mounted) {
        _pinController.clear();
        setState(() => _isSetupMode = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Admin PIN successfully established!"),
          backgroundColor: AppColors.brandGreen,
        ));
        context.go(AppRoutes.adminDashboard);
      }
      return;
    }

    if (input == _duressPin) {
      await DatabaseHelper.instance.logSecurityEvent("DURESS_ALARM",
          "Admin entered Duress PIN. Potential physical threat detected.",
          severity: "CRITICAL");
      if (mounted) {
        _pinController.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("System Error: 0x800F001. Handshake failed."),
            backgroundColor: Colors.blueGrey));
      }
      return;
    }

    AdminRole grantedRole = await AdminSecurityService().verifyPin(input);

    if (grantedRole != AdminRole.none) {
      String roleStr =
          grantedRole == AdminRole.superAdmin ? "Super Admin" : "Staff Admin";
      await DatabaseHelper.instance.logSecurityEvent(
          "ADMIN_ACCESS", "Successful $roleStr login via PIN.",
          severity: "MEDIUM");
      _failedAttempts = 0;
      _pinController.clear();
      if (mounted) context.go(AppRoutes.adminDashboard);
    } else {
      _failedAttempts++;
      final currentAttempts = _failedAttempts;
      _pinController.clear();

      await DatabaseHelper.instance.logSecurityEvent(
          "AUTH_FAILURE", "Failed admin PIN attempt ($currentAttempts/3).",
          severity: "MEDIUM");

      if (!mounted) return;

      if (_failedAttempts >= 3) {
        int lockoutSeconds = 60; // Locked for 1 minute
        await AdminSecurityService().setLockout(lockoutSeconds);
        if (mounted) {
          setState(() => _remainingSeconds = lockoutSeconds);
          _startLockoutTimer();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "SECURITY ALERT: System locked for $lockoutSeconds seconds."),
            backgroundColor: Colors.red,
          ));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Invalid Admin PIN. $_failedAttempts/3 attempts."),
          backgroundColor: Colors.orange,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLocked = _isSystemLocked();
    bool isKiosk = AppEnvironment().shouldShowVirtualKeyboard;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      resizeToAvoidBottomInset: !isKiosk, // Respect native keyboard on desktop
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                padding: EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  top: 40.0,
                  bottom: (isKeyboardVisible && isKiosk) ? 350.0 : 40.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // SHIELD ICON
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2D3243),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      isLocked
                          ? "System Locked"
                          : (_isSetupMode ? "Setup Required" : "Admin Access"),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3243),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      isLocked
                          ? "Brute force protection active."
                          : (_isSetupMode
                              ? "Create a secure 6-digit PIN"
                              : "Enter PIN to manage kiosk settings"),
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    Container(
                      constraints: const BoxConstraints(maxWidth: 450),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isLocked) ...[
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    "$_remainingSeconds",
                                    style: const TextStyle(
                                        fontSize: 64,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.redAccent),
                                  ),
                                  const Text("SECONDS REMAINING",
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2)),
                                ],
                              ),
                            ),
                          ] else ...[
                            const Text(
                              "Admin PIN",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: _pinFieldKey,
                              controller: _pinController,
                              focusNode: _pinFocusNode,
                              obscureText: _isObscured,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                              readOnly: isKiosk,
                              onTap: () {
                                if (isKiosk) {
                                  showKeyboard(_pinController, _pinFieldKey,
                                      type: KeyboardType.numeric, maxLength: 6);
                                } else {
                                  _pinFocusNode.requestFocus();
                                }
                              },
                              decoration: InputDecoration(
                                hintText: "******",
                                counterText: "",
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF2D3243), width: 1.5),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isObscured
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _isObscured = !_isObscured),
                                ),
                              ),
                              onSubmitted: (_) => _handleLogin(),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D3243),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  _isSetupMode ? "Setup PIN" : "Unlock System",
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
