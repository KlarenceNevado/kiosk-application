import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../user_history/data/history_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/models/user_model.dart';
import '../../../health_check/models/vital_signs_model.dart';
import '../../services/pdf_report_service.dart';
import '../../../../core/services/security/encryption_service.dart';

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  bool _isGenerating = false;
  String _dateFilter = "ALL TIME";

  List<VitalSigns> _getFilteredRecords(List<VitalSigns> allRecords) {
    if (_dateFilter == "ALL TIME") return allRecords;

    final now = DateTime.now();
    DateTime start;

    if (_dateFilter == "THIS WEEK") {
      start = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(start.year, start.month, start.day);
    } else if (_dateFilter == "THIS MONTH") {
      start = DateTime(now.year, now.month, 1);
    } else if (_dateFilter == "LAST MONTH") {
      start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month, 0);
      return allRecords
          .where((r) =>
              r.phtTimestamp.isAfter(start) &&
              r.phtTimestamp.isBefore(end.add(const Duration(days: 1))))
          .toList();
    } else {
      return allRecords;
    }

    return allRecords
        .where((r) =>
            r.phtTimestamp.isAfter(start.subtract(const Duration(seconds: 1))))
        .toList();
  }

  Future<void> _exportToCSV() async {
    setState(() => _isGenerating = true);
    try {
      final historyRepo = context.read<HistoryRepository>();
      final authRepo = context.read<AuthRepository>();
      final records = _getFilteredRecords(historyRepo.records);

      if (records.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("No records found for the selected filter."),
            backgroundColor: Colors.orange));
        return;
      }

      List<List<dynamic>> rows = [];
      rows.add([
        "Record ID",
        "Patient Name",
        "Phone Number",
        "Date",
        "Time",
        "Heart Rate",
        "Systolic BP",
        "Diastolic BP",
        "Oxygen",
        "Temperature",
        "BMI",
        "BMI Category",
        "Status"
      ]);

      for (var record in records) {
        final user = authRepo.users.firstWhere((u) => u.id == record.userId,
            orElse: () => User(
                id: '',
                firstName: 'Unknown',
                middleInitial: '',
                lastName: '',
                sitio: '',
                phoneNumber: '',
                pinCode: '',
                dateOfBirth: DateTime.now(),
                gender: ''));
        rows.add([
          record.id,
          user.fullName,
          user.phoneNumber,
          DateFormat('yyyy-MM-dd').format(record.phtTimestamp),
          DateFormat('HH:mm').format(record.phtTimestamp),
          record.heartRate,
          record.systolicBP,
          record.diastolicBP,
          record.oxygen,
          record.temperature,
          record.bmi ?? '',
          record.bmiCategory ?? '',
          record.status
        ]);
      }

      String csv = const ListToCsvConverter().convert(rows);
      final encryptedCsv = EncryptionService().encryptData(csv);
      
      final directory = await getApplicationDocumentsDirectory();
      final String filePath =
          '${directory.path}/kiosk_report_${DateTime.now().millisecondsSinceEpoch}.csv.aes';
      final File file = File(filePath);
      await file.writeAsString(encryptedCsv);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Report exported successfully to documents folder."),
        backgroundColor: AppColors.brandGreen,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Export Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyRepo = context.watch<HistoryRepository>();
    final authRepo = context.watch<AuthRepository>();
    final filteredRecords = _getFilteredRecords(historyRepo.records);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Health Analytics & Reports",
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandDark)),
                  Text(
                      "Insights and regulatory data for Barangay Health management.",
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
              Row(
                children: [
                  _buildActionButton(
                    icon: Icons.table_chart,
                    label: "CSV EXPORT",
                    color: Colors.blue[700]!,
                    onPressed: _exportToCSV,
                    isLoading: _isGenerating,
                  ),
                  const SizedBox(width: 12),
                  _buildActionButton(
                    icon: Icons.picture_as_pdf,
                    label: "MONTHLY PDF",
                    color: AppColors.brandGreen,
                    onPressed: () =>
                        PdfReportService.generateAndPrintMonthlyReport(
                            users: authRepo.users, records: filteredRecords),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildFilterBar(),
          const SizedBox(height: 32),
          _buildSummaryCards(filteredRecords, authRepo.users.length),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  flex: 3,
                  child:
                      _buildDistributionChart(filteredRecords, authRepo.users)),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _buildRiskPieChart(filteredRecords)),
            ],
          ),
          const SizedBox(height: 32),
          _buildDataTable(filteredRecords, authRepo.users),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          const Text("Time Period:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          _buildFilterChip("ALL TIME"),
          _buildFilterChip("THIS WEEK"),
          _buildFilterChip("THIS MONTH"),
          _buildFilterChip("LAST MONTH"),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final active = _dateFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (val) {
          if (val) setState(() => _dateFilter = label);
        },
        selectedColor: AppColors.brandGreen,
        labelStyle: TextStyle(color: active ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _buildSummaryCards(List<VitalSigns> records, int patientCount) {
    final highRisk = records
        .where((r) =>
            r.status.toUpperCase().contains('HIGH') ||
            r.status.toUpperCase().contains('EMERGENCY'))
        .length;
    return Row(
      children: [
        _buildStatCard("Total Screenings", records.length.toString(),
            Icons.analytics, Colors.blue),
        const SizedBox(width: 20),
        _buildStatCard("High Risk Cases", highRisk.toString(), Icons.warning,
            Colors.orange),
        const SizedBox(width: 20),
        _buildStatCard("Total Patients", patientCount.toString(), Icons.people,
            AppColors.brandGreen),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color)),
            const SizedBox(width: 20),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionChart(List<VitalSigns> records, List<User> users) {
    // Map of Sitio to count
    Map<String, int> sitioStats = {};
    for (var r in records) {
      final user = users.firstWhere((u) => u.id == r.userId,
          orElse: () => User(
              id: '',
              firstName: '',
              middleInitial: '',
              lastName: '',
              sitio: 'Unknown',
              phoneNumber: '',
              pinCode: '',
              dateOfBirth: DateTime.now(),
              gender: ''));
      sitioStats[user.sitio] = (sitioStats[user.sitio] ?? 0) + 1;
    }

    final sortedKeys = sitioStats.keys.toList()..sort();

    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Case Distribution by Sitio",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (sitioStats.values.isEmpty
                    ? 10
                    : sitioStats.values
                            .reduce((a, b) => a > b ? a : b)
                            .toDouble() +
                        2),
                barGroups: List.generate(sortedKeys.length, (i) {
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                        toY: sitioStats[sortedKeys[i]]!.toDouble(),
                        color: AppColors.brandGreen,
                        width: 22,
                        borderRadius: BorderRadius.circular(4))
                  ]);
                }),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) => Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(sortedKeys[val.toInt()].split(' ').last,
                            style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 30)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskPieChart(List<VitalSigns> records) {
    if (records.isEmpty) return const SizedBox();

    int normal =
        records.where((r) => r.status.toUpperCase() == 'NORMAL').length;
    int high =
        records.where((r) => r.status.toUpperCase() == 'HIGH RISK').length;
    int emergency =
        records.where((r) => r.status.toUpperCase() == 'EMERGENCY').length;

    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Risk Level Summary",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 40),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                      value: normal.toDouble(),
                      color: AppColors.brandGreen,
                      title: 'Normal',
                      radius: 50,
                      titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  PieChartSectionData(
                      value: high.toDouble(),
                      color: Colors.orange,
                      title: 'High',
                      radius: 50,
                      titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  PieChartSectionData(
                      value: emergency.toDouble(),
                      color: Colors.red,
                      title: 'Emerg',
                      radius: 50,
                      titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildPieLegend(),
        ],
      ),
    );
  }

  Widget _buildPieLegend() {
    return Column(
      children: [
        _legendItem("Normal", AppColors.brandGreen),
        _legendItem("High Risk", Colors.orange),
        _legendItem("Emergency", Colors.red),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]),
    );
  }

  Widget _buildDataTable(List<VitalSigns> records, List<User> users) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Recent Screenings Detail",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(3),
              3: FlexColumnWidth(1.5)
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade50),
                children: const [
                  Padding(
                      padding: EdgeInsets.all(12),
                      child: Text("PATIENT",
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  Padding(
                      padding: EdgeInsets.all(12),
                      child: Text("DATE",
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  Padding(
                      padding: EdgeInsets.all(12),
                      child: Text("VITALS",
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  Padding(
                      padding: EdgeInsets.all(12),
                      child: Text("STATUS",
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
              ...records.reversed.take(15).map((r) {
                final user = users.firstWhere((u) => u.id == r.userId,
                    orElse: () => User(
                        id: '',
                        firstName: 'Unknown',
                        middleInitial: '',
                        lastName: '',
                        sitio: '',
                        phoneNumber: '',
                        pinCode: '',
                        dateOfBirth: DateTime.now(),
                        gender: ''));
                return TableRow(
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(user.fullName)),
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child:
                            Text(DateFormat('MMM dd').format(r.phtTimestamp))),
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                            "${r.systolicBP}/${r.diastolicBP} | ${r.temperature}°C")),
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: _statusChip(r.status)),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color = Colors.grey;
    if (status.toUpperCase() == 'NORMAL') color = AppColors.brandGreen;
    if (status.toUpperCase().contains('HIGH')) color = Colors.orange;
    if (status.toUpperCase().contains('EMERGENCY')) color = Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return ElevatedButton.icon(
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : Icon(icon, size: 18),
      label: Text(label),
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
}
