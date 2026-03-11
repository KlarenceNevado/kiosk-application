import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../user_history/data/history_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../health_check/models/vital_signs_model.dart';
import '../../../auth/models/user_model.dart';

class AdminValidationTab extends StatefulWidget {
  const AdminValidationTab({super.key});

  @override
  State<AdminValidationTab> createState() => _AdminValidationTabState();
}

class _AdminValidationTabState extends State<AdminValidationTab> {
  VitalSigns? _selectedRecord;
  final TextEditingController _remarksController = TextEditingController();
  String _selectedStatus = 'verified_true';
  String _selectedAction = 'none';

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<HistoryRepository, AuthRepository>(
      builder: (context, historyRepo, authRepo, child) {
        final pendingRecords =
            historyRepo.records.where((r) => r.status == 'pending').toList();

        return Row(
          children: [
            // Left Pane: Pending List
            Container(
              width: 350,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey[300]!)),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppColors.brandDark.withValues(alpha: 0.05),
                    child: Text(
                      "Pending Readings (${pendingRecords.length})",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Expanded(
                    child: pendingRecords.isEmpty
                        ? const Center(
                            child: Text("No readings pending validation.",
                                style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: pendingRecords.length,
                            itemBuilder: (context, index) {
                              final record = pendingRecords[index];
                              // Needs follow up if BP is high or BMI is obese
                              final isCritical = record.systolicBP >= 140 ||
                                  record.diastolicBP >= 90 ||
                                  record.bmiCategory == "Obese";

                              return ListTile(
                                leading: Icon(Icons.favorite,
                                    color: isCritical
                                        ? Colors.red
                                        : AppColors.brandGreen),
                                title: Text(
                                    DateFormat('MMM dd, hh:mm a')
                                        .format(record.phtTimestamp),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    "BP: ${record.systolicBP}/${record.diastolicBP} • HR: ${record.heartRate}"),
                                trailing: isCritical
                                    ? const Icon(Icons.circle,
                                        color: Colors.red, size: 12)
                                    : null,
                                selected: _selectedRecord?.id == record.id,
                                selectedTileColor:
                                    AppColors.brandGreen.withValues(alpha: 0.1),
                                onTap: () {
                                  setState(() {
                                    _selectedRecord = record;
                                    _remarksController.text =
                                        record.remarks ?? '';
                                    _selectedStatus =
                                        'verified_true'; // default
                                    _selectedAction = 'none';
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            // Right Pane: Validation Details
            Expanded(
              child: _selectedRecord == null
                  ? const Center(
                      child: Text("Select a reading from the left to validate",
                          style: TextStyle(color: Colors.grey, fontSize: 16)))
                  : _buildValidationDetails(authRepo),
            ),
          ],
        );
      },
    );
  }

  Widget _buildValidationDetails(AuthRepository authRepo) {
    final record = _selectedRecord!;
    final user = authRepo.users.firstWhere(
      (u) => u.id == record.userId,
      orElse: () => User(
          id: '',
          firstName: 'Unknown',
          middleInitial: '',
          lastName: 'Patient',
          sitio: '',
          phoneNumber: '',
          pinCode: '123456',
          dateOfBirth: DateTime.now(),
          gender: ''),
    );

    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Reading Details & Verification",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDark)),
            const SizedBox(height: 24),

            // Patient & Vitals Summary
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[300]!)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("PATIENT INFO",
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(user.fullName,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(user.phoneNumber),
                          Text("${user.age} yrs • ${user.gender}"),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("VITALS RECORDED",
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                              "BP: ${record.systolicBP}/${record.diastolicBP} mmHg",
                              style: const TextStyle(fontSize: 16)),
                          Text("Heart Rate: ${record.heartRate} bpm",
                              style: const TextStyle(fontSize: 16)),
                          Text("SpO2: ${record.oxygen}%",
                              style: const TextStyle(fontSize: 16)),
                          Text("Temp: ${record.temperature}°C",
                              style: const TextStyle(fontSize: 16)),
                          Text("BMI: ${record.bmiCategory}",
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // BHW Assessment
            const Text("BHW Remarks/Notes",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _remarksController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    "Enter clinical assessment or notes from patient communication...",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            // Verification Status
            const Text("Verification Status",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<String>(
                      value: 'verified_true',
                      // ignore: deprecated_member_use
                      groupValue: _selectedStatus,
                      // ignore: deprecated_member_use
                      onChanged: (val) =>
                          setState(() => _selectedStatus = val!),
                      activeColor: AppColors.brandGreen,
                    ),
                    const Text("Verified - True Reading"),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<String>(
                      value: 'verified_false',
                      // ignore: deprecated_member_use
                      groupValue: _selectedStatus,
                      // ignore: deprecated_member_use
                      onChanged: (val) =>
                          setState(() => _selectedStatus = val!),
                      activeColor: Colors.red,
                    ),
                    const Text("Verified - False Reading / Anomaly"),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<String>(
                      value: 'requires_retest',
                      // ignore: deprecated_member_use
                      groupValue: _selectedStatus,
                      // ignore: deprecated_member_use
                      onChanged: (val) =>
                          setState(() => _selectedStatus = val!),
                      activeColor: Colors.orange,
                    ),
                    const Text("Requires Re-test"),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Follow-up Actions
            const Text("Follow-up Action",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedAction,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                        value: 'none', child: Text("No Action Needed")),
                    DropdownMenuItem(
                        value: 'advise_clinic',
                        child: Text("Advise Clinic Visit Remotely")),
                    DropdownMenuItem(
                        value: 'home_visit',
                        child: Text("Schedule Home Visit")),
                    DropdownMenuItem(
                        value: 'refer_municipal',
                        child: Text("Refer to Municipal Health Office")),
                  ],
                  onChanged: (val) => setState(() => _selectedAction = val!),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Submit Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() => _selectedRecord = null);
                  },
                  child: const Text("CANCEL",
                      style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text("SAVE & VALIDATE",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 20),
                  ),
                  onPressed: () {
                    final updatedRecord = record.copyWith(
                      status: _selectedStatus,
                      remarks: _remarksController.text,
                      followUpAction: _selectedAction,
                    );

                    context
                        .read<HistoryRepository>()
                        .updateRecord(updatedRecord);

                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Validation saved successfully."),
                      backgroundColor: AppColors.brandGreen,
                    ));

                    setState(() => _selectedRecord = null);
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
