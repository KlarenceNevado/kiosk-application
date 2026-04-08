import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/routes.dart';
import '../../../core/widgets/flow_animated_button.dart';
import '../../../core/widgets/virtual_keyboard.dart';
import '../domain/i_auth_repository.dart';
import '../models/user_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/mixins/virtual_keyboard_mixin.dart';
import '../../../core/services/system/app_environment.dart';

class RegisterScreen extends StatefulWidget {
  final bool isAdmin;
  const RegisterScreen({super.key, this.isAdmin = false});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with VirtualKeyboardMixin {
  bool get isKiosk => AppEnvironment().shouldShowVirtualKeyboard;

  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _middleInitController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();

  final GlobalKey _nameKey = GlobalKey();
  final GlobalKey _lastNameKey = GlobalKey();
  final GlobalKey _phoneKey = GlobalKey();

  String? _selectedSitio;
  String? _selectedGender;
  DateTime? _selectedDate;
  bool _isPasswordVisible = false;

  final List<String> _sitios = [
    "Sitio Ayala",
    "Sitio Mahabang Buhangin",
    "Sitio Sampalucan",
    "Sitio Hulo",
    "Sitio Labak",
    "Sitio Macaraigan",
    "Sitio Gabihan",
  ];
  final List<String> _genders = ["Male", "Female"];

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
                primary: AppColors.brandGreen,
                onPrimary: Colors.white,
                onSurface: AppColors.brandDark),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('MMMM dd, yyyy').format(picked);
      });
    }
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedSitio == null ||
          _selectedGender == null ||
          _selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please fill all fields")));
        return;
      }

      if (_phoneController.text.length != 11) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Phone number must be exactly 11 digits")));
        return;
      }

      final newUser = User(
        id: const Uuid().v4(),
        firstName: _firstNameController.text.trim(),
        middleInitial: _middleInitController.text.trim(),
        lastName: _lastNameController.text.trim(),
        sitio: _selectedSitio!,
        phoneNumber: _phoneController.text.trim(),
        pinCode: '123456',
        gender: _selectedGender!,
        dateOfBirth: _selectedDate!,
      );

      final error = await context.read<IAuthRepository>().registerUser(newUser);

      if (error == null && mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(widget.isAdmin ? AppRoutes.adminUsers : AppRoutes.home);
        }
      } else if (mounted && error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleInitController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<IAuthRepository>().isLoading;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          toolbarHeight: 56,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: AppColors.brandDark, size: 22),
            onPressed: () => context.pop(),
          ),
          title: Text(
              AppLocalizations.of(context)?.patientRegistration ??
                  "Patient Registration",
              style: const TextStyle(
                  color: AppColors.brandDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
          centerTitle: true,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    padding: EdgeInsets.only(
                        bottom:
                            (isKeyboardVisible && !widget.isAdmin && isKiosk)
                                ? 350
                                : 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                              AppLocalizations.of(context)?.patientInfoForm ??
                                  "Patient Registration Form",
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(fontSize: 30),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 6),
                          const Text("Fill in the details to join us",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 20),
                          _buildSectionHeader(
                              AppLocalizations.of(context)?.demographics ??
                                  "Demographics"),
                          Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                    color:
                                        Colors.black.withValues(alpha: 0.05)),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.01),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5))
                                ]),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                          flex: 3,
                                          child: _buildTextField(
                                              AppLocalizations.of(context)
                                                      ?.firstName ??
                                                  "First Name",
                                              _firstNameController,
                                              Icons.person_outline,
                                              key: _nameKey)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          flex: 1,
                                          child: _buildTextField(
                                              AppLocalizations.of(context)
                                                      ?.middleInitial ??
                                                  "M.I.",
                                              _middleInitController,
                                              null,
                                              maxLength: 2)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTextField(
                                      AppLocalizations.of(context)?.lastName ??
                                          "Last Name",
                                      _lastNameController,
                                      Icons.person,
                                      type: KeyboardType.text,
                                      key: _lastNameKey),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                          child: GestureDetector(
                                              onTap: () => _selectDate(context),
                                              child: AbsorbPointer(
                                                  child: _buildTextField(
                                                      AppLocalizations.of(
                                                                  context)
                                                              ?.dateOfBirth ??
                                                          "Date of Birth",
                                                      _dobController,
                                                      Icons.calendar_today,
                                                      readOnly: true)))),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child:
                                              DropdownButtonFormField<String>(
                                        decoration: _inputDecoration(
                                            AppLocalizations.of(context)
                                                    ?.gender ??
                                                "Gender",
                                            Icons.wc),
                                        initialValue: _selectedGender,
                                        items: _genders
                                            .map((g) => DropdownMenuItem(
                                                value: g,
                                                child: Text(g,
                                                    style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w700))))
                                            .toList(),
                                        onChanged: (val) => setState(
                                            () => _selectedGender = val),
                                      )),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildSectionHeader(
                              AppLocalizations.of(context)?.contact ??
                                  "Contact Info"),
                          Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                    color:
                                        Colors.black.withValues(alpha: 0.05)),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.01),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5))
                                ]),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    decoration: _inputDecoration(
                                        AppLocalizations.of(context)?.sitio ??
                                            "Sitio / Location",
                                        Icons.location_on_outlined),
                                    initialValue: _selectedSitio,
                                    items: _sitios
                                        .map((sitio) => DropdownMenuItem(
                                            value: sitio,
                                            child: Text(sitio,
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w700))))
                                        .toList(),
                                    onChanged: (val) =>
                                        setState(() => _selectedSitio = val),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    key: _phoneKey,
                                    controller: _phoneController,
                                    readOnly: !widget.isAdmin && isKiosk,
                                    keyboardType: (widget.isAdmin || !isKiosk)
                                        ? TextInputType.phone
                                        : TextInputType.none,
                                    onTap: (widget.isAdmin || !isKiosk)
                                        ? null
                                        : () => showKeyboard(
                                            _phoneController, _phoneKey,
                                            type: KeyboardType.numeric,
                                            maxLength: 11),
                                    obscureText: !_isPasswordVisible,
                                    maxLength: 11,
                                    validator: (val) =>
                                        val != null && val.length == 11
                                            ? null
                                            : AppLocalizations.of(context)
                                                    ?.phoneLengthError ??
                                                "Phone must be 11 digits",
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5),
                                    decoration: _inputDecoration(
                                            AppLocalizations.of(context)
                                                    ?.phoneNumber ??
                                                "Phone Number (11 digits)",
                                            Icons.phone_android)
                                        .copyWith(
                                      counterText: "",
                                      suffixIcon: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 12),
                                        child: IconButton(
                                          iconSize: 24,
                                          icon: Icon(_isPasswordVisible
                                              ? Icons.visibility
                                              : Icons.visibility_off),
                                          onPressed: () => setState(() =>
                                              _isPasswordVisible =
                                                  !_isPasswordVisible),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (isLoading)
                            const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.brandGreen))
                          else
                            FlowAnimatedButton(
                              child: ElevatedButton(
                                onPressed: _handleRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brandGreen,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 60),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50)),
                                  elevation: 6,
                                  shadowColor: AppColors.brandGreen
                                      .withValues(alpha: 0.3),
                                ),
                                child: Text(
                                    AppLocalizations.of(context)
                                            ?.createPatientRecord ??
                                        "CREATE PATIENT RECORD",
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.0)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 12),
      child: Text(title,
          style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.brandDark.withValues(alpha: 0.6))),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, IconData? icon,
      {int? maxLength,
      GlobalKey? key,
      KeyboardType type = KeyboardType.text,
      bool readOnly = false}) {
    return TextFormField(
      key: key,
      controller: controller,
      readOnly: (!widget.isAdmin && isKiosk) && !readOnly,
      keyboardType: (widget.isAdmin || !isKiosk)
          ? TextInputType.text
          : TextInputType.none,
      onTap: (readOnly || widget.isAdmin || !isKiosk)
          ? null
          : () => showKeyboard(controller, key, type: type),
      maxLength: maxLength,
      validator: (val) => val == null || val.isEmpty
          ? AppLocalizations.of(context)?.required ?? "Required"
          : null,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      decoration: _inputDecoration(label, icon).copyWith(counterText: ""),
    );
  }

  InputDecoration _inputDecoration(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
      filled: true,
      fillColor: Colors.white,
      counterText: "",
      prefixIcon: icon != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Icon(icon, color: AppColors.brandGreen, size: 24),
            )
          : null,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 2)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 2)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide:
              const BorderSide(color: AppColors.brandGreen, width: 2.0)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    );
  }
}
