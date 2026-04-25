import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../user_history/domain/i_history_repository.dart';
import '../../../auth/domain/i_auth_repository.dart';
import '../../../health_check/models/vital_signs_model.dart';
import '../../../auth/models/user_model.dart';
import '../../../../core/utils/health_thresholds.dart';

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
    return Consumer2<IHistoryRepository, IAuthRepository>(
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
                              final user = authRepo.users.firstWhere(
                                (u) => u.id == record.userId,
                                orElse: () => User.empty(),
                              );
                              final isCritical =
                                  HealthThresholds.isCritical(user, record);
                              final isSelected =
                                  _selectedRecord?.id == record.id;

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.brandGreen
                                          .withValues(alpha: 0.08)
                                      : Colors.transparent,
                                  border: Border(
                                    left: BorderSide(
                                      color: isSelected
                                          ? AppColors.brandGreen
                                          : Colors.transparent,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  leading: Icon(Icons.favorite,
                                      color: isCritical
                                          ? Colors.red
                                          : AppColors.brandGreen),
                                  title: Text(
                                      DateFormat('MMM dd, hh:mm a')
                                          .format(record.phtTimestamp),
                                      style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? AppColors.brandDark
                                              : Colors.black)),
                                  subtitle: Text(
                                      "BP: ${record.systolicBP}/${record.diastolicBP} • HR: ${record.heartRate}"),
                                  trailing: isCritical
                                      ? const Icon(Icons.warning_amber_rounded,
                                          color: Colors.red, size: 20)
                                      : (isSelected
                                          ? const Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              size: 14,
                                              color: AppColors.brandGreen)
                                          : null),
                                  selected: isSelected,
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
                                ),
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
                  ? _buildEmptyState()
                  : _buildValidationDetails(authRepo),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fact_check_outlined, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text("Ready for Validation",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          const Text("Select a reading from the left to start verification.",
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildValidationDetails(IAuthRepository authRepo) {
    final record = _selectedRecord!;
    final user = authRepo.users.firstWhere(
      (u) => u.id == record.userId,
      orElse: () => User(
          id: '',
          firstName: 'Unknown',
          middleInitial: '',
          lastName: 'Resident',
          sitio: '',
          phoneNumber: '',
          pinCode: '123456',
          dateOfBirth: DateTime.now(),
          gender: '',
          username: 'unknown'),
    );

    final riskFactors = HealthThresholds.evaluate(user, record);

    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text("Reading Details & Verification",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandDark)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: record.isSynced ? Colors.blue[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(record.isSynced ? Icons.cloud_done : Icons.cloud_off,
                          size: 14,
                          color: record.isSynced ? Colors.blue : Colors.grey),
                      const SizedBox(width: 6),
                      Text(record.isSynced ? "Cloud Synced" : "Local Only",
                          style: TextStyle(
                              fontSize: 12,
                              color: record.isSynced
                                  ? Colors.blue
                                  : Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Resident & Vitals Summary
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
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("RESIDENT INFO",
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    AppColors.brandGreen.withValues(alpha: 0.1),
                                child: Text(user.firstName[0],
                                    style: const TextStyle(
                                        color: AppColors.brandGreen,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user.fullName,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    Text("ID: ${user.username}",
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(Icons.phone, user.phoneNumber),
                          _buildInfoRow(Icons.location_on, user.sitio),
                          _buildInfoRow(Icons.person,
                              "${user.age} yrs • ${user.gender}"),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 48),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("VITALS RECORDED",
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          const SizedBox(height: 12),
                          _buildVitalMetric("Blood Pressure",
                              "${record.systolicBP}/${record.diastolicBP} mmHg",
                              isWarning: riskFactors
                                  .any((r) => r.contains("BP"))),
                          _buildVitalMetric("Heart Rate", "${record.heartRate} bpm",
                              isWarning: riskFactors
                                  .any((r) => r.contains("Heart Rate"))),
                          _buildVitalMetric("Oxygen Level", "${record.oxygen}%",
                              isWarning:
                                  riskFactors.any((r) => r.contains("O2"))),
                          _buildVitalMetric(
                              "Temperature", "${record.temperature}°C",
                              isWarning:
                                  riskFactors.any((r) => r.contains("Fever"))),
                          _buildVitalMetric("BMI",
                              "${record.bmi?.toStringAsFixed(1) ?? 'N/A'} (${record.bmiCategory})",
                              isWarning: riskFactors
                                  .any((r) => r.contains("Obesity"))),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Useful Function Details: Clinical Context
            if (riskFactors.isNotEmpty) ...[
              const Text("Automated Risk Evaluation",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: riskFactors
                      .map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 16, color: Colors.red),
                                const SizedBox(width: 8),
                                Text(r,
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Clinical Reference Ranges
            const Text("Clinical Reference Ranges (For this Resident)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!)),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(3),
                  2: FlexColumnWidth(2),
                },
                children: [
                  _buildTableHeader(),
                  _buildTableRow("Blood Pressure", _getBPReference(user.age),
                      "mmHg"),
                  _buildTableRow(
                      "Heart Rate", _getHRReference(user.age, user.gender), "bpm"),
                  _buildTableRow("Oxygen (SpO2)", "95% - 100%", "%"),
                  _buildTableRow("Temperature", "36.5°C - 37.5°C", "°C"),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // BHW Assessment
            const Text("BHW Remarks/Notes",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _remarksController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    "Enter clinical assessment or notes from resident communication...",
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
                _buildStatusRadio('verified_true', "Verified - True Reading",
                    AppColors.brandGreen),
                _buildStatusRadio('verified_false',
                    "Verified - False Reading / Anomaly", Colors.red),
                _buildStatusRadio(
                    'requires_retest', "Requires Re-test", Colors.orange),
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

            const SizedBox(height: 48),

            // Submit Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() => _selectedRecord = null);
                  },
                  child: const Text("CANCEL",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text("SAVE & VALIDATE",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final updatedRecord = record.copyWith(
                      status: _selectedStatus,
                      remarks: _remarksController.text,
                      followUpAction: _selectedAction,
                    );

                    context
                        .read<IHistoryRepository>()
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

  Widget _buildInfoRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.brandDark)),
        ],
      ),
    );
  }

  Widget _buildVitalMetric(String label, String value,
      {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(color: Colors.grey)),
          Text(value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isWarning ? Colors.red : AppColors.brandDark,
              )),
          if (isWarning) ...[
            const SizedBox(width: 8),
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: Colors.red),
          ],
        ],
      ),
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey[100]),
      children: const [
        Padding(
            padding: EdgeInsets.all(12),
            child: Text("Vital Sign",
                style: TextStyle(fontWeight: FontWeight.bold))),
        Padding(
            padding: EdgeInsets.all(12),
            child: Text("Normal Range",
                style: TextStyle(fontWeight: FontWeight.bold))),
        Padding(
            padding: EdgeInsets.all(12),
            child:
                Text("Unit", style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }

  TableRow _buildTableRow(String label, String range, String unit) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(12), child: Text(label)),
        Padding(
            padding: const EdgeInsets.all(12),
            child: Text(range,
                style: const TextStyle(fontWeight: FontWeight.w600))),
        Padding(padding: const EdgeInsets.all(12), child: Text(unit)),
      ],
    );
  }

  Widget _buildStatusRadio(String value, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          // ignore: deprecated_member_use
          groupValue: _selectedStatus,
          // ignore: deprecated_member_use
          onChanged: (val) => setState(() => _selectedStatus = val!),
          activeColor: color,
        ),
        Text(label),
      ],
    );
  }

  String _getBPReference(int age) {
    if (age <= 1) return "72/37 - 104/56";
    if (age <= 3) return "86/42 - 106/63";
    if (age <= 5) return "89/46 - 112/72";
    if (age <= 12) return "97/57 - 120/80";
    if (age <= 17) return "110/64 - 131/83";
    if (age >= 65) return "90/60 - 150/90";
    return "90/60 - 140/90";
  }

  String _getHRReference(int age, String gender) {
    if (age <= 1) return "100 - 160";
    if (age <= 3) return "90 - 150";
    if (age <= 5) return "80 - 140";
    if (age <= 12) return "70 - 120";
    if (age <= 17) return "60 - 100";
    return gender.toLowerCase() == 'female' ? "65 - 105" : "60 - 100";
  }
}
