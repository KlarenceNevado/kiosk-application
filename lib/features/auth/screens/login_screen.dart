import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/routes.dart';
import '../../../core/widgets/kiosk_scaffold.dart';
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
  Timer? _exitTimer;

  void _startExitTimer() {
    _exitTimer = Timer(const Duration(seconds: 3), () {
      _showAdminExitDialog();
    });
  }

  void _stopExitTimer() {
    _exitTimer?.cancel();
  }

  void _showAdminExitDialog() {
    final passwordController = TextEditingController();
    final env = AppEnvironment();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(env.isKiosk ? "Exit Kiosk" : "Admin Exit"),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: "Admin Password"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (passwordController.text == env.adminExitPassword) {
                if (env.isKiosk) {
                  // On the physical kiosk, exit the app entirely
                  exit(0);
                } else {
                  // On other platforms, go to admin dashboard
                  Navigator.pop(dialogContext);
                  context.go(AppRoutes.adminDashboard);
                }
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text("Incorrect password")));
              }
            },
            child: Text(env.isKiosk ? "Exit App" : "Exit to Admin"),
          ),
        ],
      ),
    );
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

    if (success == null && mounted) {
      context.go(AppRoutes.home);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ?? "Invalid credentials"), backgroundColor: Colors.red));
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
                        Container(
                          padding: const EdgeInsets.all(28), // Larger container
                          decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brandGreen.withValues(alpha: 0.15),
                                  blurRadius: 20, // More shadow
                                )
                              ]),
                          child: GestureDetector(
                            onTapDown: (_) => _startExitTimer(),
                            onTapUp: (_) => _stopExitTimer(),
                            onTapCancel: () => _stopExitTimer(),
                            child: const Icon(Icons.medical_services_rounded,
                                size: 60, color: AppColors.brandGreen), // Enlarged from 48
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text("Kiosk Access",
                            style: TextStyle(
                                fontSize: 42, // High-Accessibility enlargement from 28
                                fontWeight: FontWeight.w900,
                                color: AppColors.brandDark,
                                letterSpacing: -1.0)),
                        const SizedBox(height: 8),
                        const Text("Secure Patient Login",
                            style: TextStyle(
                                fontSize: 20, // Enlarged from 16
                                color: Colors.grey,
                                fontWeight: FontWeight.w500)),

                        const SizedBox(height: 32),

                        // --- MAIN CARD ---
                        Container(
                          padding: const EdgeInsets.all(32), // More room
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 30, // Deeper shadow
                                    offset: const Offset(0, 10))
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
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18, // Enlarged from 15
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
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18, // Enlarged
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
                                      suffixIcon: IconButton(
                                        iconSize: 24,
                                        icon: Icon(_isPasswordVisible
                                            ? Icons.visibility
                                            : Icons.visibility_off),
                                        onPressed: () => setState(() =>
                                            _isPasswordVisible = !_isPasswordVisible),
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
                                            minimumSize: const Size(double.infinity, 64), // Enlarged height
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                                            elevation: 4),
                                        child: Text(
                                            AppLocalizations.of(context)?.accessRecord ?? "ACCESS RECORD",
                                            style: const TextStyle(
                                                fontSize: 22, // High-Accessibility font size
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.0)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                side: BorderSide(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(50)),
                          ),
                          child: Text(
                              AppLocalizations.of(context)?.noAccountCreate ?? "No Account? Create New Record",
                              style: const TextStyle(
                                  color: AppColors.brandDark,
                                  fontSize: 18, // Enlarged
                                  fontWeight: FontWeight.w900)),
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
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 18),
      filled: true,
      fillColor: Colors.grey[50],
      prefixIcon: Icon(icon, color: AppColors.brandDark, size: 28), // Larger icons
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200)),
    );
  }
}
