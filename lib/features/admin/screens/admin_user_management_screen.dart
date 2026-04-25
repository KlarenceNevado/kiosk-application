import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/routes.dart';
import '../../../core/services/database/database_helper.dart';
import '../../../core/services/security/encryption_service.dart';
import '../../auth/domain/i_auth_repository.dart';
import '../../auth/models/user_model.dart';
import '../../user_history/domain/i_history_repository.dart';
import '../../health_check/models/vital_signs_model.dart';
import 'package:intl/intl.dart';
import '../../../core/services/system/app_environment.dart';
import '../../../core/mixins/virtual_keyboard_mixin.dart';
import '../../../core/widgets/virtual_keyboard.dart';
import '../widgets/admin_resident_profile_sidebar.dart';

enum SortOption { nameAsc, nameDesc, newest, oldest }

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen>
    with VirtualKeyboardMixin {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _searchFieldKey = GlobalKey();
  String _searchQuery = "";
  String _selectedSitioFilter = "All Sitios";
  SortOption _currentSort = SortOption.nameAsc;

  bool _isPiiVisible = false;

  bool _isSelectionMode = false;
  final Set<String> _selectedUserIds = {};
  final pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  // EDIT FORM FOCUS NODES
  final FocusNode _firstNameFocusNode = FocusNode();
  final FocusNode _lastNameFocusNode = FocusNode();
  final FocusNode _miFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    pinController.dispose();
    _pinFocusNode.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _miFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
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

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedUserIds.clear();
    });
  }

  // --- SECURE EXPORT ---
  Future<void> _exportUsersToCSV(List<User> users) async {
    try {
      List<List<dynamic>> csvData = [
        [
          "ID",
          "First Name",
          "Last Name",
          "MI",
          "Sitio",
          "Phone",
          "Gender",
          "DOB"
        ],
      ];

      for (var u in users) {
        csvData.add([
          u.id,
          u.firstName,
          u.lastName,
          u.middleInitial,
          u.sitio,
          u.phoneNumber,
          u.gender,
          u.dateOfBirth.toIso8601String()
        ]);
      }

      String csvString = const ListToCsvConverter().convert(csvData);
      final encryptedData = EncryptionService().encryptData(csvString);

      final directory = await getApplicationDocumentsDirectory();
      final path =
          "${directory.path}/users_export_secure_${DateTime.now().millisecondsSinceEpoch}.csv.aes";
      final file = File(path);
      await file.writeAsString(encryptedData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Secured Export saved to: $path"),
          backgroundColor: AppColors.brandGreen));
      await DatabaseHelper.instance.logSecurityEvent("USER_EXPORT",
          "Encrypted user list exported (${users.length} records)",
          severity: "MEDIUM", userId: "ADMIN");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Export failed: $e"), backgroundColor: Colors.red));
    }
  }

  // --- PRIVACY TOGGLE ---
  void _togglePiiVisibility() async {
    if (!_isPiiVisible) {
      await DatabaseHelper.instance.logSecurityEvent(
          "PII_REVEAL", "Admin revealed resident list PII.",
          severity: "HIGH", userId: "ADMIN");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("PII Revealed. Action Logged.")));
      }
    }
    setState(() {
      _isPiiVisible = !_isPiiVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = context.watch<IAuthRepository>();
    final allUsers = authRepo.users;

    var filteredUsers = allUsers.where((u) {
      final matchesSearch =
          u.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              u.sitio.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesSitio = _selectedSitioFilter == "All Sitios" ||
          u.sitio == _selectedSitioFilter;
      return matchesSearch && matchesSitio;
    }).toList();

    final sitioStats = _allSitios.map((sitio) {
      return {
        'name': sitio,
        'count': allUsers.where((u) => u.sitio == sitio).length
      };
    }).toList();

    switch (_currentSort) {
      case SortOption.nameAsc:
        filteredUsers.sort((a, b) => a.lastName.compareTo(b.lastName));
        break;
      case SortOption.nameDesc:
        filteredUsers.sort((a, b) => b.lastName.compareTo(a.lastName));
        break;
      case SortOption.newest:
        filteredUsers = filteredUsers.reversed.toList();
        break;
      case SortOption.oldest:
        break;
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
            _isSelectionMode
                ? "${_selectedUserIds.length} Selected"
                : "User Database",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor:
            _isSelectionMode ? Colors.blueGrey : AppColors.brandDark,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(_isSelectionMode ? Icons.close : Icons.arrow_back),
          onPressed: () {
            if (_isSelectionMode) {
              _toggleSelectionMode();
            } else {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.adminDashboard);
              }
            }
          },
        ),
        actions: [
          if (!_isSelectionMode) _buildModernRevealToggle(),
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed:
                  _selectedUserIds.isEmpty ? null : () => _confirmBulkDelete(),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: "Secure Export",
              onPressed: () => _exportUsersToCSV(filteredUsers),
            ),
            PopupMenuButton<SortOption>(
              icon: const Icon(Icons.sort),
              onSelected: (val) => setState(() => _currentSort = val),
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: SortOption.nameAsc, child: Text("Name (A-Z)")),
                const PopupMenuItem(
                    value: SortOption.nameDesc, child: Text("Name (Z-A)")),
                const PopupMenuItem(
                    value: SortOption.newest, child: Text("Newest First")),
                const PopupMenuItem(
                    value: SortOption.oldest, child: Text("Oldest First")),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: "Select Multiple",
              onPressed: _toggleSelectionMode,
            ),
          ]
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('${AppRoutes.register}?admin=true'),
              icon: const Icon(Icons.add),
              label: const Text("New User"),
              backgroundColor: AppColors.brandGreen,
            ),
      body: Column(
        children: [
          _buildStickyHeader(allUsers.length, sitioStats),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 24, right: 24, top: 8, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isPiiVisible)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.2))),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline,
                              color: Colors.orange, size: 18),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                                "Privacy Mode: Personal data is masked for security.",
                                style: TextStyle(
                                    color: Colors.deepOrange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                          TextButton(
                            onPressed: _togglePiiVisibility,
                            child: const Text("REVEAL NOW",
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  _buildFilterRow(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: filteredUsers.length,
                            padding: const EdgeInsets.only(bottom: 100),
                            itemBuilder: (context, index) {
                              return _buildUserCard(filteredUsers[index]);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    final isSelected = _selectedUserIds.contains(user.id);
    final historyRepo = context.read<IHistoryRepository>();
    final userRecords =
        historyRepo.records.where((r) => r.userId == user.id).toList();

    VitalSigns? lastRecord;
    if (userRecords.isNotEmpty) {
      userRecords.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      lastRecord = userRecords.first;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? AppColors.brandGreen : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          )),
      color: isSelected
          ? AppColors.brandGreen.withValues(alpha: 0.05)
          : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _isSelectionMode
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedUserIds.remove(user.id);
                  } else {
                    _selectedUserIds.add(user.id);
                  }
                });
              }
            : () => _showResidentProfile(user, historyRepo.records),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (_isSelectionMode)
                Checkbox(
                    value: isSelected,
                    activeColor: AppColors.brandGreen,
                    onChanged: (val) => setState(() => val == true
                        ? _selectedUserIds.add(user.id)
                        : _selectedUserIds.remove(user.id)))
              else
                _buildUserAvatar(user, lastRecord?.status),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _isPiiVisible
                            ? user.fullName
                            : _maskText(user.fullName),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(user.sitio,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(width: 12),
                        Icon(Icons.calendar_today,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          lastRecord != null
                              ? "Last seen: ${DateFormat('MMM dd').format(lastRecord.phtTimestamp)}"
                              : "No screenings yet",
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!_isSelectionMode) _buildCardActions(user),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(User user, String? status) {
    Color statusColor = Colors.grey.shade300;
    if (status != null) {
      if (status.toUpperCase().contains('EMERGENCY')) {
        statusColor = Colors.red;
      } else if (status.toUpperCase().contains('HIGH')) {
        statusColor = Colors.orange;
      } else if (status.toUpperCase().contains('NORMAL')) {
        statusColor = AppColors.brandGreen;
      }
    }

    return Stack(
      children: [
        CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.brandGreen.withValues(alpha: 0.1),
            child: Text(
                user.firstName.isNotEmpty
                    ? user.firstName[0].toUpperCase()
                    : "?",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.brandGreen))),
        if (status != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCardActions(User user) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: "View Health History",
          child: IconButton(
            icon:
                Icon(Icons.history_edu, color: Colors.grey.shade600, size: 20),
            onPressed: () {
              final historyRepo = context.read<IHistoryRepository>();
              _showResidentProfile(user, historyRepo.records);
            },
          ),
        ),
        Tooltip(
          message: "Edit Resident",
          child: IconButton(
            icon: const Icon(Icons.edit_note_rounded,
                color: Colors.blue, size: 22),
            onPressed: () => _showEditSheet(user),
          ),
        ),
        Tooltip(
          message: "Delete Record",
          child: IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent, size: 22),
            onPressed: () => _confirmDelete([user.id]),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyHeader(int total, List<Map<String, dynamic>> stats) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildHeaderStat("All Registrants", total.toString(),
                    Icons.people, AppColors.brandGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: stats
                          .map((s) => _buildSitioChip(s['name'], s['count']))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(
      String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold)),
              Text(val,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSitioChip(String name, int count) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(count.toString(),
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSitioFilter,
                isExpanded: true,
                icon:
                    const Icon(Icons.filter_list, color: AppColors.brandGreen),
                items: ["All Sitios", ..._allSitios]
                    .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedSitioFilter = val!),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 48,
            child: TextField(
              key: _searchFieldKey,
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search Name...",
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        })
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernRevealToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: _isPiiVisible
            ? Colors.redAccent.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: _togglePiiVisibility,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Icon(_isPiiVisible ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(_isPiiVisible ? "HIDE PII" : "REVEAL PII",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  void _showResidentProfile(User user, List<VitalSigns> allRecords) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Profile",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => Container(),
      transitionBuilder: (ctx, anim, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(anim),
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              elevation: 16,
              child: SizedBox(
                width: 450,
                child: AdminResidentProfileSidebar(
                  resident: user,
                  residentRecords: allRecords,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _maskText(String input) {
    if (input.length <= 2) return "**";
    return "${input[0]}******* ${input.split(' ').last[0]}*****";
  }

  // --- EDIT SHEET ---
  void _showEditSheet(User user) {
    if (!_isPiiVisible) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please 'Reveal Data' before editing.")));
      return;
    }

    final nameController = TextEditingController(text: user.firstName);
    final lastController = TextEditingController(text: user.lastName);
    final miController = TextEditingController(text: user.middleInitial);
    final phoneController = TextEditingController(text: user.phoneNumber);
    String selectedSitio = user.sitio;
    String selectedRole = user.role.toLowerCase();

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
                const Text("Edit Resident",
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSheetField(
                          "First Name", nameController, _firstNameFocusNode),
                      const SizedBox(height: 12),
                      _buildSheetField(
                          "Last Name", lastController, _lastNameFocusNode),
                      const SizedBox(height: 12),
                      _buildSheetField(
                          "Middle Initial", miController, _miFocusNode,
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
                      _buildSheetField(
                          "Phone", phoneController, _phoneFocusNode,
                          keyboardType: TextInputType.phone, maxLength: 11),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        items: const [
                          DropdownMenuItem(
                              value: 'patient',
                              child: Row(children: [
                                Icon(Icons.person, size: 18),
                                SizedBox(width: 8),
                                Text("Resident")
                              ])),
                          DropdownMenuItem(
                              value: 'bhw',
                              child: Row(children: [
                                Icon(Icons.medical_services,
                                    size: 18, color: Colors.blue),
                                SizedBox(width: 8),
                                Text("Health Worker (BHW)")
                              ])),
                          DropdownMenuItem(
                              value: 'admin',
                              child: Row(children: [
                                Icon(Icons.admin_panel_settings,
                                    size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text("Administrator")
                              ])),
                        ],
                        onChanged: (val) =>
                            setSheetState(() => selectedRole = val!),
                        decoration: const InputDecoration(
                            labelText: "Account Role",
                            border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
              if (AppEnvironment().shouldShowVirtualKeyboard) ...[
                const SizedBox(height: 16),
                VirtualKeyboard(
                  controller:
                      nameController, // Default, but tapping field should switch it
                  onSubmit: () => Navigator.pop(ctx),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final updatedUser = user.copyWith(
                      firstName: nameController.text.trim(),
                      lastName: lastController.text.trim(),
                      middleInitial: miController.text.trim(),
                      sitio: selectedSitio,
                      phoneNumber: phoneController.text.trim(),
                      role: selectedRole,
                    );
                    await context
                        .read<IAuthRepository>()
                        .updateUser(updatedUser);
                    if (!mounted) return;
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Resident updated successfully"),
                          backgroundColor: AppColors.brandGreen));
                    }
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

  Widget _buildSheetField(
      String label, TextEditingController controller, FocusNode focusNode,
      {TextInputType keyboardType = TextInputType.text, int? maxLength}) {
    final bool showVirtualKeyboard = AppEnvironment().shouldShowVirtualKeyboard;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: showVirtualKeyboard,
      keyboardType: keyboardType,
      maxLength: maxLength,
      onTap: () {
        if (showVirtualKeyboard) {
          showKeyboard(controller, null,
              type: keyboardType == TextInputType.number ||
                      keyboardType == TextInputType.phone
                  ? KeyboardType.numeric
                  : KeyboardType.text,
              maxLength: maxLength);
        } else {
          focusNode.requestFocus();
        }
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[50],
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.brandGreen, width: 2)),
        counterText: "",
      ),
    );
  }

  // --- DELETE MODAL ---
  void _confirmDelete(List<String> userIds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text("Confirm Deletion",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900])),
            const SizedBox(height: 8),
            Text(
                "Are you sure you want to delete ${userIds.length} record(s)? This action cannot be undone.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            const Text("Enter Admin PIN to confirm:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              textAlign: TextAlign.center,
              obscureText: true,
              readOnly: AppEnvironment().shouldShowVirtualKeyboard,
              onTap: () {
                if (AppEnvironment().shouldShowVirtualKeyboard) {
                  showKeyboard(pinController, null,
                      type: KeyboardType.numeric, maxLength: 6);
                }
              },
              style: const TextStyle(
                  fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                  hintText: "******",
                  border: OutlineInputBorder(),
                  counterText: ""),
              onSubmitted: (_) =>
                  _performDelete(userIds, pinController.text, ctx),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () =>
                    _performDelete(userIds, pinController.text, ctx),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Confirm Delete",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _performDelete(List<String> userIds, String pin, BuildContext ctx) {
    if (pin == "123456") {
      Navigator.pop(ctx);
      final repo = context.read<IAuthRepository>();
      for (var id in userIds) {
        repo.deleteUser(id);
      }
      DatabaseHelper.instance.logSecurityEvent("USER_DELETE",
          "Admin performed bulk delete of ${userIds.length} users.",
          severity: "HIGH", userId: "ADMIN");
      setState(() {
        _isSelectionMode = false;
        _selectedUserIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${userIds.length} User(s) deleted."),
          backgroundColor: Colors.red));
      pinController.clear();
    } else {
      DatabaseHelper.instance.logSecurityEvent(
          "AUTH_FAILURE", "Failed PIN attempt during deletion authorization.",
          severity: "MEDIUM", userId: "ADMIN");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Incorrect PIN."), backgroundColor: Colors.red));
    }
  }

  void _confirmBulkDelete() {
    _confirmDelete(_selectedUserIds.toList());
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No matching residents found.",
              style: TextStyle(
                  color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
