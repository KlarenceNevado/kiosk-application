import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/routes.dart';
import '../../../core/widgets/kiosk_scaffold.dart';
import '../../../core/widgets/logo_glow.dart';
import '../../../core/widgets/flow_animated_button.dart';
import '../../../core/widgets/virtual_keyboard.dart';
import '../domain/i_auth_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/mixins/virtual_keyboard_mixin.dart';
import '../../../core/services/system/app_environment.dart';
import '../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with VirtualKeyboardMixin {
  bool get isKiosk => AppEnvironment().shouldShowVirtualKeyboard;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _nameFieldKey = GlobalKey();
  final GlobalKey _phoneFieldKey = GlobalKey();

  List<User> _filteredUsers = [];
  User? _selectedUser;
  bool _isPasswordVisible = false;

  // --- Admin Hold Logic ---
  Timer? _adminHoldTimer;
  double _adminHoldScale = 1.0;
  final int _holdDurationSeconds = 10;
  void _showAdminExitDialog() {
    final passwordController = TextEditingController();
    final env = AppEnvironment();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        bool isDialogPasswordVisible = false;
        return StatefulBuilder(
          builder: (context, setState) {
            final bool keyboardActive = isKeyboardVisible;
            
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Align(
                alignment: keyboardActive ? const Alignment(0, -1.0) : Alignment.center,
                child: Container(
                  constraints: BoxConstraints(maxWidth: keyboardActive ? 380 : 440),
                  padding: EdgeInsets.all(keyboardActive ? 16 : 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3E9), 
                    borderRadius: BorderRadius.circular(keyboardActive ? 20 : 28),
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
                      if (!keyboardActive) ...[
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
                        const SizedBox(height: 12),
                        const Text(
                          "Administrator credentials required to exit kiosk mode.",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ] else ...[
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline, color: AppColors.brandGreen, size: 18),
                            SizedBox(width: 8),
                            Text("ADMIN ACCESS REQUIRED", 
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brandGreen, letterSpacing: 1.2)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: !isDialogPasswordVisible,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: keyboardActive ? null : "Admin Password",
                          hintText: keyboardActive ? "Password" : null,
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.brandGreen),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isDialogPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: AppColors.brandGreen,
                            ),
                            onPressed: () => setState(() => isDialogPasswordVisible = !isDialogPasswordVisible),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        onTap: () {
                          if (env.isKiosk) {
                            showKeyboard(passwordController, null, type: KeyboardType.text);
                            Future.delayed(const Duration(milliseconds: 150), () => setState(() {}));
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
                                if (env.isKiosk) {
                                  exit(0);
                                } else {
                                  Navigator.pop(dialogContext);
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
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
    ).then((_) {
      if (mounted && isKeyboardVisible) Navigator.of(context).pop();
    });
  }

  void _startAdminHold() {
    _adminHoldTimer?.cancel();
    setState(() => _adminHoldScale = 1.1); // Pulse up animation
    
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
    if (mounted) {
      setState(() => _adminHoldScale = 1.0);
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _phoneController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    final allUsers = context.read<IAuthRepository>().users;
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = [];
      } else {
        _filteredUsers = allUsers.where((u) {
          final fullName = "${u.firstName} ${u.lastName}".toLowerCase();
          return fullName.contains(query);
        }).toList();
      }
    });
  }

  void _onUserSelected(User user) {
    setState(() {
      _selectedUser = user;
      _searchController.text = "${user.firstName} ${user.lastName}";
      _filteredUsers = [];
    });
    _searchFocusNode.unfocus();
  }

  Future<void> _handleLogin() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a patient first")));
      return;
    }

    if (_phoneController.text.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Phone number must be 11 digits")));
      return;
    }

    final success = await context.read<IAuthRepository>().login(
          _selectedUser!.firstName,
          _phoneController.text,
        );

    if (success == null) {
      if (!mounted) return;
      context.go(AppRoutes.home);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = context.watch<IAuthRepository>().users;
    final isLoading = context.watch<IAuthRepository>().isLoading;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        if (mounted) setState(() => _filteredUsers = []);
      },
      child: KioskScaffold(
        title: AppLocalizations.of(context)?.appTitle ?? "Kiosk Health",
        showBackButton: false,
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.help),
            icon: const Row(
              children: [
                Icon(Icons.help_outline, color: AppColors.brandDark, size: 24),
                SizedBox(width: 4),
                Text("Help", style: TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
        body: SingleChildScrollView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                    left: 24.0,
                    right: 24.0,
                    top: 24.0, // Reduced top
                    bottom: (isKeyboardVisible && isKiosk) ? 350.0 : 32.0),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // --- HEADER ---
                        GestureDetector(
                          onLongPressStart: (_) => _startAdminHold(),
                          onLongPressEnd: (_) => _stopAdminHold(),
                          onLongPressCancel: () => _stopAdminHold(),
                          child: AnimatedScale(
                            scale: _adminHoldScale,
                            duration: const Duration(milliseconds: 200),
                            child: const LogoGlow(
                              size: 140, // Adjusted size
                              child: Icon(Icons.medical_services_rounded,
                                  size: 84, color: AppColors.brandGreen),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16), // Reduced from 32
                        Text("Kiosk Access",
                            style: Theme.of(context).textTheme.displayLarge),
                        const SizedBox(height: 8), // Reduced from 12
                        const Text("Secure Patient Login",
                            style: TextStyle(
                                fontSize: 18, // Reduced from 20
                                color: Colors.grey,
                                fontWeight: FontWeight.w500)),

                        const SizedBox(height: 24), // Reduced from 32

                        // --- MAIN CARD ---
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32), // Reduced vertical from 48
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02), // Reduced opacity
                                    blurRadius: 20, // Reduced from 30
                                    offset: const Offset(0, 10)) // Reduced from 15
                              ]),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      AppLocalizations.of(context)?.findYourAccount ?? "1. Find Your Account",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, // Reduced from w900
                                          fontSize: 18,
                                          color: Colors.grey)),
                                  const SizedBox(height: 12),

                                  if (users.isEmpty)
                                    _buildNoUsersWarning()
                                  else
                                    TextField(
                                      key: _nameFieldKey,
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      readOnly: isKiosk,
                                      showCursor: true,
                                      cursorColor: AppColors.brandDark,
                                      onTap: () {
                                        setState(() {
                                          _onSearchChanged();
                                        });
                                        if (isKiosk) {
                                          showKeyboard(_searchController, _nameFieldKey);
                                        }
                                      },
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), // Larger text
                                      decoration: _inputDecoration(
                                          AppLocalizations.of(context)?.searchName ?? "Type Name...",
                                          Icons.person_search_rounded),
                                    ),

                                  const SizedBox(height: 24),

                                  Text(
                                      AppLocalizations.of(context)?.enterPassword ?? "2. Verify Identity",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, // Reduced from w900
                                          fontSize: 18,
                                          color: Colors.grey)),
                                  const SizedBox(height: 12),
                                  TextField(
                                    key: _phoneFieldKey,
                                    controller: _phoneController,
                                    obscureText: !_isPasswordVisible,
                                    readOnly: isKiosk,
                                    maxLength: 11,
                                    onTap: () {
                                      if (isKiosk) {
                                        showKeyboard(_phoneController, _phoneFieldKey,
                                            type: KeyboardType.numeric, maxLength: 11);
                                      }
                                    },
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                                    decoration: _inputDecoration(
                                            AppLocalizations.of(context)?.phoneNumber ?? "Phone Number (11 digits)",
                                            Icons.lock_person_rounded)
                                        .copyWith(
                                      counterText: "",
                                      contentPadding: const EdgeInsets.only(left: 28, right: 12, top: 26, bottom: 26),
                                      suffixIcon: Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: IconButton(
                                          constraints: const BoxConstraints(), // Fixes 'lumalampas' issue
                                          padding: EdgeInsets.zero,
                                          iconSize: 24,
                                          icon: Icon(_isPasswordVisible
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                              color: AppColors.brandGreen),
                                          onPressed: () => setState(() =>
                                              _isPasswordVisible = !_isPasswordVisible),
                                        ),
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
                                            minimumSize: const Size(double.infinity, 64), // Reduced from 72
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                                            elevation: 8,
                                            shadowColor: AppColors.brandGreen.withValues(alpha: 0.4),
                                        ),
                                        child: Text(
                                            AppLocalizations.of(context)?.accessRecord ?? "ACCESS RECORD",
                                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                              color: Colors.white,
                                              fontSize: 20, // Reduced from 22
                                              letterSpacing: 2.0,
                                            )),
                                      ),
                                    ),
                                ],
                              ),

                              // --- Result List ---
                              if (_filteredUsers.isNotEmpty)
                                Positioned(
                                  top: 100, left: 0, right: 0,
                                  child: Material(
                                    elevation: 15, // Higher elevation
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.white,
                                    child: Container(
                                      constraints: const BoxConstraints(maxHeight: 280),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero,
                                        itemCount: _filteredUsers.length,
                                        separatorBuilder: (c, i) =>
                                            const Divider(height: 1),
                                        itemBuilder: (ctx, i) {
                                          final u = _filteredUsers[i];
                                          return ListTile(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                            leading: CircleAvatar(
                                              backgroundColor: AppColors.brandGreen.withValues(alpha: 0.1),
                                              child: Text(u.firstName[0], style: const TextStyle(color: AppColors.brandGreen, fontWeight: FontWeight.bold)),
                                            ),
                                            title: Text("${u.firstName} ${u.lastName}",
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), // Larger list item
                                            subtitle: Text("Sitio: ${u.sitio}", style: const TextStyle(fontSize: 15)),
                                            onTap: () => _onUserSelected(u),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // --- REGISTER LINK ---
                        TextButton(
                          onPressed: () => context.push(AppRoutes.register),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16), // Reduced from 20
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                side: BorderSide(color: Colors.grey.shade200, width: 2),
                                borderRadius: BorderRadius.circular(50)),
                          ),
                          child: Text(
                              AppLocalizations.of(context)?.noAccountCreate ?? "No Account? Create New Record",
                              style: const TextStyle(
                                  color: AppColors.brandDark,
                                  fontSize: 16, // Reduced from 18
                                  fontWeight: FontWeight.w700)), // Reduced from w900
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoUsersWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade100)),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 12),
          Expanded(child: Text("Waiting for data synchronization...", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(icon, color: AppColors.brandGreen, size: 28),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 2)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 2)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: AppColors.brandGreen, width: 2.5)),
    );
  }
}
