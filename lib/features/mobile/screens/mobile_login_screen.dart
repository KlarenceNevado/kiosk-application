import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // for Timer
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/flow_animated_button.dart';
import '../../auth/domain/i_auth_repository.dart';
import '../../auth/models/user_model.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/route_names.dart';

class MobileLoginScreen extends StatefulWidget {
  const MobileLoginScreen({super.key});

  @override
  State<MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends State<MobileLoginScreen> {
  final _nameController = TextEditingController(); // Account Name
  final _phoneController = TextEditingController(); // Phone (Password)

  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _nameFieldKey = GlobalKey();

  bool _obscurePassword = true;

  bool _isLoading = false;
  String? _errorMessage;

  // Search Autocomplete State
  List<User> _filteredUsers = [];
  bool _showSuggestions = false;
  User? _selectedUser;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.removeListener(_onSearchChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final query = _nameController.text.trim();

    if (_selectedUser != null &&
        _selectedUser!.fullName != query &&
        _selectedUser!.firstName != query) {
      _selectedUser = null;
    }

    if (query.isEmpty) {
      setState(() {
        _filteredUsers = [];
        _showSuggestions = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final authRepo = Provider.of<IAuthRepository>(context, listen: false);
        final results = await authRepo.searchPatients(query);
        if (mounted) {
          setState(() {
            _filteredUsers = results;
            // Show suggestions even if empty, so we can show "No results"
            _showSuggestions = query.isNotEmpty && _selectedUser == null;
          });
        }
      } catch (e) {
        debugPrint("Ignore search fail: $e");
      }
    });
  }

  void _selectUser(User user) {
    setState(() {
      _selectedUser = user;
      _nameController.text = user.fullName;
      _showSuggestions = false;
      _searchFocusNode.unfocus();
    });
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final nameInput = _selectedUser?.firstName ?? _nameController.text.trim();
      final phoneInput = _phoneController.text.trim();

      if (nameInput.isEmpty || phoneInput.isEmpty) {
        throw Exception("Please enter both Name and Phone Number.");
      }

      // Secure Login against Repository
      final authRepo = context.read<IAuthRepository>();
      final String? errorOrNull = await authRepo.login(nameInput, phoneInput);

      if (errorOrNull != null) {
        throw Exception(errorOrNull);
      }

      final loggedInUser = authRepo.currentUser;
      if (loggedInUser == null) {
        throw Exception("Authentication failed unexpectedly.");
      }

      if (mounted) {
        context.go(AppRoutes.patientHome);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll("Exception: ", "");
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    int? maxLength,
    FocusNode? focusNode,
    Key? fieldKey,
    Widget? suffixIcon,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      maxLength: maxLength,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        counterText: "",
        prefixIcon: Icon(icon, color: AppColors.brandGreen),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: AppColors.brandGreen, width: 2)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior
          .translucent, // Allow taps to pass through to underlying inputs
      onTap: () {
        FocusScope.of(context).unfocus();
        if (_showSuggestions) setState(() => _showSuggestions = false);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // --- LOGO & HEADER ---
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: AppColors.brandGreenLight,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.brandGreen.withValues(alpha: 0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ]),
                      child: const Icon(Icons.monitor_heart_rounded,
                          size: 64, color: AppColors.brandGreenDark),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text(
                    "Patient Portal",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h1.copyWith(fontSize: 32),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Access your health check history",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),

                  const SizedBox(height: 48),

                  // --- LOGIN FORM ---
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          )
                        ]),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          children: [
                            _buildTextField(
                                fieldKey: _nameFieldKey,
                                controller: _nameController,
                                focusNode: _searchFocusNode,
                                label: "Account Name",
                                icon: Icons.person_outline_rounded,
                                keyboardType: TextInputType
                                    .text, // Better for OS keyboard triggers
                                textCapitalization: TextCapitalization.words,
                                suffixIcon: _selectedUser != null
                                    ? const Icon(Icons.check_circle,
                                        color: AppColors.brandGreen)
                                    : (_nameController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear,
                                                color: Colors.grey),
                                            onPressed: () {
                                              _nameController.clear();
                                              setState(() {
                                                _selectedUser = null;
                                                _filteredUsers = [];
                                                _showSuggestions = false;
                                              });
                                            },
                                          )
                                        : null)),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _phoneController,
                              label: "Registered Phone Number",
                              icon: Icons.lock_outline_rounded,
                              keyboardType:
                                  TextInputType.number, // Native number pad
                              obscureText: _obscurePassword,
                              maxLength: 11,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                            color: Colors.red, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: FlowAnimatedButton(
                                isDisabled: _isLoading,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brandGreen,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5))
                                      : const Text("Access Records",
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_showSuggestions)
                          Positioned(
                            top: 65,
                            left: 0,
                            right: 0,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                              shadowColor: Colors.black.withValues(alpha: 0.2),
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 250),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: _filteredUsers.isEmpty
                                    ? Container(
                                        padding: const EdgeInsets.all(16),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.search_off,
                                                color: Colors.grey),
                                            SizedBox(width: 12),
                                            Text("No matches found",
                                                style: TextStyle(
                                                    color: Colors.grey,
                                                    fontStyle:
                                                        FontStyle.italic)),
                                          ],
                                        ),
                                      )
                                    : ListView.separated(
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
                                            leading: const CircleAvatar(
                                              backgroundColor:
                                                  AppColors.brandGreenLight,
                                              child: Icon(Icons.person,
                                                  color: AppColors.brandGreen),
                                            ),
                                            title: Text(user.fullName,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            subtitle: Text(user.sitio,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey)),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
