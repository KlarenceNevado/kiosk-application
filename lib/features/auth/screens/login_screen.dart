import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/routes.dart';
import '../../../core/widgets/flow_animated_button.dart';
import '../../../core/widgets/virtual_keyboard.dart';
import '../domain/i_auth_repository.dart';
import '../models/user_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/mixins/virtual_keyboard_mixin.dart';
import '../../../core/services/system/app_environment.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with VirtualKeyboardMixin {
  bool get isKiosk => AppEnvironment().shouldShowVirtualKeyboard;

  // PERSISTENT CONTROLLERS
  final _phoneController = TextEditingController();
  final _searchController = TextEditingController();

  // FOCUS NODES
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();

  // KEYS FOR SCROLLING
  final GlobalKey _nameFieldKey = GlobalKey();
  final GlobalKey _passwordFieldKey = GlobalKey();

  // _scrollController provided by mixin

  User? _selectedUser;
  bool _hasError = false;
  bool _isPasswordVisible = false;

  // SEARCH STATE
  List<User> _filteredUsers = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    // Listen to repository changes to refresh filtered list instantly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<IAuthRepository>().addListener(_onSearchChanged);
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    try {
      context.read<IAuthRepository>().removeListener(_onSearchChanged);
    } catch (_) {}
    _phoneController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _phoneFocusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }

  // --- REAL-TIME FILTER LOGIC ---
  void _onSearchChanged() {
    if (!mounted) return;
    final query = _searchController.text.toLowerCase().trim();
    final allUsers = context.read<IAuthRepository>().users;

    // Reset selection if text doesn't match selected user
    if (_selectedUser != null &&
        _selectedUser!.fullName != _searchController.text) {
      _selectedUser = null;
    }

    if (query.isEmpty) {
      setState(() {
        _filteredUsers = [];
        _showSuggestions = false;
      });
      return;
    }

    // STRICT FILTERING: Match start of words only
    final matches = allUsers.where((user) {
      final fullName = user.fullName.toLowerCase();

      // 1. Check if the full name starts with query
      if (fullName.startsWith(query)) return true;

      // 2. Check if any individual word starts with query
      final parts = fullName.split(' ');
      for (final part in parts) {
        if (part.startsWith(query)) return true;
      }

      return false;
    }).toList();

    setState(() {
      _filteredUsers = matches;
      // Show suggestions if we have matches and no user is currently selected
      _showSuggestions = matches.isNotEmpty && _selectedUser == null;
    });
  }

  void _selectUser(User user) {
    setState(() {
      _selectedUser = user;
      _searchController.text = user.fullName;
      _showSuggestions = false; // Hide dropdown immediately after selection
    });
    // Optional: Hide keyboard after selection to focus on password
    if (isKeyboardVisible) Navigator.pop(context);
  }

  void _handleLogin() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please search and select your name first.")));
      return;
    }

    final phoneInput = _phoneController.text.trim();
    if (phoneInput.isEmpty) {
      setState(() => _hasError = true);
      return;
    }

    if (phoneInput.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Phone number must be exactly 11 digits (e.g. 09123456789)."),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (isKeyboardVisible) Navigator.pop(context);

    final error = await context
        .read<IAuthRepository>()
        .login(_selectedUser!.firstName, phoneInput);

    if (error == null && mounted) {
      context.go(AppRoutes.home);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error ?? "Incorrect Phone Number. Please try again."),
            backgroundColor: Colors.red),
      );
    }
  }


  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Need Assistance?"),
        content: const Text(
            "If you cannot log in or forgot your number, please approach the Barangay Health Worker desk."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Close"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = context.watch<IAuthRepository>().users;
    final isLoading = context.watch<IAuthRepository>().isLoading;

    return GestureDetector(
      onTap: () {
        if (isKeyboardVisible) Navigator.pop(context);
        setState(() => _showSuggestions = false);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: !isKiosk,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            TextButton.icon(
              onPressed: _showHelpDialog,
              icon: const Icon(Icons.help_outline,
                  color: AppColors.brandDark, size: 24),
              label: const Text("Help",
                  style: TextStyle(
                      color: AppColors.brandDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
            const SizedBox(width: 16),
          ],
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
                      bottom: (isKeyboardVisible && isKiosk)
                          ? 350.0
                          : 40.0), // Reduced bottom padding to prevent overflow
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // --- HEADER SECTION ---
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.brandGreen.withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 4,
                              )
                            ]),
                        child: const Icon(Icons.medical_services_rounded,
                            size: 60, color: AppColors.brandGreen),
                      ),
                      const SizedBox(height: 24),
                      const Text("Kiosk Access",
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppColors.brandDark,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 8),
                      const Text("Secure Patient Login",
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500)),

                      const SizedBox(height: 24),


                      // --- MAIN CARD (STACKED FOR DROPDOWN) ---
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12))
                            ]),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // 1. FORM CONTENT (The Base Layer)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    AppLocalizations.of(context)
                                            ?.findYourAccount ??
                                        "Find Your Account",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.grey)),
                                const SizedBox(height: 12),

                                if (users.isEmpty)
                                  _buildNoUsersWarning()
                                else
                                  // SEARCH INPUT (Base field)
                                  TextField(
                                    key: _nameFieldKey,
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    readOnly: isKiosk,
                                    showCursor: true,
                                    cursorColor: AppColors.brandDark,
                                    cursorWidth: 2.0,
                                    onTap: () {
                                      setState(() {
                                        _selectedUser = null;
                                        _showSuggestions =
                                            _filteredUsers.isNotEmpty;
                                      });
                                      if (isKiosk) {
                                        showKeyboard(
                                            _searchController, _nameFieldKey,
                                            type: KeyboardType.text);
                                      } else {
                                        _searchFocusNode.requestFocus();
                                      }
                                    },
                                    decoration: _inputDecor(
                                            AppLocalizations.of(context)!
                                                .searchName,
                                            Icons.person_search_rounded)
                                        .copyWith(
                                            suffixIcon: _selectedUser != null
                                                ? const Icon(Icons.check_circle,
                                                    color: AppColors.brandGreen,
                                                    size: 28)
                                                : (_searchController
                                                        .text.isNotEmpty
                                                    ? IconButton(
                                                        icon: const Icon(
                                                            Icons.clear,
                                                            color: Colors.grey),
                                                        onPressed: () {
                                                          _searchController
                                                              .clear();
                                                          setState(() {
                                                            _selectedUser =
                                                                null;
                                                            _filteredUsers = [];
                                                            _showSuggestions =
                                                                false;
                                                          });
                                                        },
                                                      )
                                                    : null)),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600),
                                  ),

                                const SizedBox(height: 24),

                                Text(
                                    AppLocalizations.of(context)!.enterPassword,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.grey)),
                                const SizedBox(height: 12),

                                // PASSWORD FIELD
                                TextField(
                                  key: _passwordFieldKey,
                                  controller: _phoneController,
                                  focusNode: _phoneFocusNode,
                                  readOnly: isKiosk,
                                  keyboardType: isKiosk
                                      ? TextInputType.none
                                      : TextInputType.phone,
                                  onTap: () {
                                    setState(() => _showSuggestions = false);
                                    if (isKiosk) {
                                      showKeyboard(
                                          _phoneController, _passwordFieldKey,
                                          type: KeyboardType.numeric,
                                          maxLength: 11);
                                    } else {
                                      _phoneFocusNode.requestFocus();
                                    }
                                  },
                                  obscureText: !_isPasswordVisible,
                                  maxLength: 11,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.0),
                                  decoration: _inputDecor(
                                          AppLocalizations.of(context)!
                                              .phoneNumber,
                                          Icons.lock_outline)
                                      .copyWith(
                                    counterText: "",
                                    hintText: "09XXXXXXXXX",
                                    hintStyle: TextStyle(
                                        fontSize: 18,
                                        letterSpacing: 1.0,
                                        color: Colors.grey[400]),
                                    errorText: _hasError
                                        ? AppLocalizations.of(context)!
                                            .incorrectCredentials
                                        : null,
                                    suffixIcon: IconButton(
                                      iconSize: 24,
                                      icon: Icon(
                                          _isPasswordVisible
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: Colors.grey),
                                      onPressed: () => setState(() =>
                                          _isPasswordVisible =
                                              !_isPasswordVisible),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 32),

                                // LOGIN BUTTON
                                if (isLoading)
                                  const Center(
                                      child: CircularProgressIndicator(
                                          color: AppColors.brandGreen))
                                else
                                  SizedBox(
                                    width: double.infinity,
                                    height: 54,
                                    child: FlowAnimatedButton(
                                      isDisabled: _selectedUser == null,
                                      child: ElevatedButton(
                                        onPressed: _selectedUser != null
                                            ? _handleLogin
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.brandGreen,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                          elevation: 2,
                                          disabledBackgroundColor:
                                              Colors.grey[300],
                                        ),
                                        child: Text(
                                            AppLocalizations.of(context)!
                                                .accessRecord,
                                            style: const TextStyle(
                                                fontSize: 18,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.0)),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            // 2. SUGGESTIONS DROPDOWN (The Overlay Layer)
                            if (_showSuggestions)
                              Positioned(
                                top: 95,
                                left: 0,
                                right: 0,
                                child: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white,
                                  shadowColor:
                                      Colors.black.withValues(alpha: 0.2),
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(maxHeight: 250),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: _filteredUsers.length,
                                      separatorBuilder: (ctx, i) =>
                                          const Divider(
                                              height: 1, color: Colors.grey),
                                      itemBuilder: (context, index) {
                                        final user = _filteredUsers[index];
                                        return ListTile(
                                          dense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 8),
                                          leading: CircleAvatar(
                                            backgroundColor: AppColors
                                                .brandGreen
                                                .withValues(alpha: 0.1),
                                            child: const Icon(Icons.person,
                                                color: AppColors.brandGreen,
                                                size: 20),
                                          ),
                                          title: Text(user.fullName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                          subtitle: Text(user.sitio,
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12)),
                                          onTap: () => _selectUser(user),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      TextButton(
                        onPressed: () => context.push(AppRoutes.register),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                                side: BorderSide(
                                    color: AppColors.brandDark
                                        .withValues(alpha: 0.1)))),
                        child: Text(
                            AppLocalizations.of(context)!.noAccountCreate,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brandDark)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNoUsersWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12)),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          SizedBox(width: 12),
          Expanded(
              child: Text("No records found on this kiosk.",
                  style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16))),
        ],
      ),
    );
  }

  InputDecoration _inputDecor(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandGreen, width: 2)),
      prefixIcon: Icon(icon, color: Colors.grey, size: 24),
      contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
    );
  }
}
