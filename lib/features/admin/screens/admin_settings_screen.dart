import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/security/admin_security_service.dart';
import '../../../core/services/system/app_environment.dart';
import '../../../core/widgets/virtual_keyboard.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late AdminRole _currentRole;

  @override
  void initState() {
    super.initState();
    _currentRole = AdminSecurityService().currentRole;
  }

  void _showPinChangeDialog({required bool isSuperAdminTarget}) {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final oldPinFocusNode = FocusNode();
    final newPinFocusNode = FocusNode();
    final confirmPinFocusNode = FocusNode();
    final bool showVirtualKeyboard = AppEnvironment().shouldShowVirtualKeyboard;

    TextEditingController activeCtrl = oldPinController;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (_, setSheetState) {
        return Container(
          height: !showVirtualKeyboard
              ? MediaQuery.of(context).size.height * 0.7
              : MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      isSuperAdminTarget
                          ? "Change Master PIN"
                          : "Change Staff PIN",
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
                  child: Column(
                    children: [
                      _buildPinField(
                          "Current PIN",
                          oldPinController,
                          activeCtrl,
                          oldPinFocusNode,
                          (c) => setSheetState(() => activeCtrl = c),
                          showVirtualKeyboard),
                      const SizedBox(height: 16),
                      _buildPinField(
                          "New PIN (6 digits)",
                          newPinController,
                          activeCtrl,
                          newPinFocusNode,
                          (c) => setSheetState(() => activeCtrl = c),
                          showVirtualKeyboard),
                      const SizedBox(height: 16),
                      _buildPinField(
                          "Confirm New PIN",
                          confirmPinController,
                          activeCtrl,
                          confirmPinFocusNode,
                          (c) => setSheetState(() => activeCtrl = c),
                          showVirtualKeyboard),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    if (newPinController.text.length < 6 ||
                        confirmPinController.text.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("New PIN must be at least 6 digits."),
                        backgroundColor: Colors.orange,
                      ));
                      return;
                    }

                    if (newPinController.text != confirmPinController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("New PINs do not match."),
                        backgroundColor: Colors.red,
                      ));
                      return;
                    }

                    // Verify old PIN
                    final role = await AdminSecurityService()
                        .verifyPin(oldPinController.text);
                    if (role == AdminRole.none) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Current PIN is incorrect."),
                        backgroundColor: Colors.red,
                      ));
                      return;
                    }

                    // Ensure permission - cannot use Staff PIN to change Master PIN
                    if (isSuperAdminTarget && role != AdminRole.superAdmin) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            "Only the Super Admin can change the Master PIN."),
                        backgroundColor: Colors.red,
                      ));
                      return;
                    }

                    bool success = false;
                    if (isSuperAdminTarget) {
                      success = await AdminSecurityService()
                          .setAdminPin(newPinController.text);
                    } else {
                      success = await AdminSecurityService()
                          .setStaffPin(newPinController.text);
                    }

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);

                    if (!mounted) return;
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("PIN successfully updated!"),
                        backgroundColor: AppColors.brandGreen,
                      ));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Failed to update PIN."),
                        backgroundColor: Colors.red,
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandDark),
                  child: const Text("UPDATE PIN",
                      style: TextStyle(
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
                    controller: activeCtrl,
                    type: KeyboardType.numeric,
                    maxLength: 6,
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

  Widget _buildPinField(
      String label,
      TextEditingController controller,
      TextEditingController active,
      FocusNode focusNode,
      Function(TextEditingController) onFocus,
      bool showVirtualKeyboard) {
    final isFocused = controller == active;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: showVirtualKeyboard,
      onTap: () {
        onFocus(controller);
        if (!showVirtualKeyboard) {
          focusNode.requestFocus();
        }
      },
      obscureText: true,
      maxLength: 6,
      textAlign: TextAlign.center,
      style: const TextStyle(
          letterSpacing: 8, fontSize: 24, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title:
            const Text("Admin Settings", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Security & PIN Management",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDark)),
            const SizedBox(height: 8),
            const Text(
                "Manage access to the Admin Dashboard. Super Admins have full access, while Staff Admins have restricted control.",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            if (_currentRole == AdminRole.superAdmin) ...[
              // SUPER ADMIN OPTIONS
              _buildSettingCard(
                title: "Change Master PIN",
                description:
                    "Update the Super Admin PIN. Requires the current Master PIN.",
                icon: Icons.shield,
                iconColor: AppColors.brandDark,
                onTap: () => _showPinChangeDialog(isSuperAdminTarget: true),
              ),
              const SizedBox(height: 16),
              _buildSettingCard(
                title: "Manage Staff PIN",
                description: "Set or update the PIN for Staff Admins.",
                icon: Icons.people,
                iconColor: Colors.blue,
                onTap: () => _showPinChangeDialog(isSuperAdminTarget: false),
              ),
            ] else ...[
              // STAFF ADMIN OPTIONS
              _buildSettingCard(
                title: "Change My PIN",
                description:
                    "Update your Staff Admin PIN. Requires your current PIN.",
                icon: Icons.lock,
                iconColor: Colors.orange,
                onTap: () => _showPinChangeDialog(isSuperAdminTarget: false),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "You are logged in as a Staff Admin. Some master security settings are hidden.",
                        style: TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard(
      {required String title,
      required String description,
      required IconData icon,
      required Color iconColor,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
