import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../user_history/domain/i_history_repository.dart';
import '../../../auth/domain/i_auth_repository.dart';
import '../../../auth/models/user_model.dart';
import '../../../health_check/models/vital_signs_model.dart';
import '../../services/pdf_report_service.dart';

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _sitioFilter = "ALL SITIOS";
  String _genderFilter = "ALL GENDERS";

  List<VitalSigns> _getFilteredRecords(List<VitalSigns> allRecords, List<User> users) {
    return allRecords.where((r) {
      final inDate = r.phtTimestamp.isAfter(_startDate.subtract(const Duration(seconds: 1))) && 
                     r.phtTimestamp.isBefore(_endDate.add(const Duration(days: 1)));
      
      if (!inDate) return false;
      
      final user = users.firstWhere((u) => u.id == r.userId, orElse: () => User.empty());
      
      final sitioMatch = _sitioFilter == "ALL SITIOS" || user.sitio == _sitioFilter;
      final genderMatch = _genderFilter == "ALL GENDERS" || user.gender.toUpperCase() == _genderFilter.toUpperCase();
      
      return sitioMatch && genderMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final historyRepo = context.watch<IHistoryRepository>();
    final authRepo = context.watch<IAuthRepository>();
    final filteredRecords = _getFilteredRecords(historyRepo.records, authRepo.users);
    
    final allSitios = authRepo.users.map((u) => u.sitio).toSet().toList()..sort();

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
                  Text("Barangay Health Reports",
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandDark)),
                  Text(
                      "Official regulatory data for LGU City Health Office transmission.",
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
              _buildActionButton(
                icon: Icons.assignment_turned_in,
                label: "OFFICIAL LGU REPORT",
                color: AppColors.brandGreen,
                onPressed: () => PdfReportService.generateOfficialLGUReport(
                  users: authRepo.users,
                  records: historyRepo.records,
                  startDate: _startDate,
                  endDate: _endDate,
                  sitio: _sitioFilter,
                  gender: _genderFilter,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildEnhancedFilterBar(allSitios),
          const SizedBox(height: 32),
          _buildSummaryCards(filteredRecords, authRepo.users.length),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  flex: 3,
                  child: RepaintBoundary(
                      child: _buildDistributionChart(filteredRecords, authRepo.users))),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: RepaintBoundary(child: _buildRiskPieChart(filteredRecords))),
            ],
          ),
          const SizedBox(height: 32),
          _buildDataTable(filteredRecords, authRepo.users),
        ],
      ),
    );
  }

  Widget _buildEnhancedFilterBar(List<String> sitios) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          // Date Range Selector
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                  initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
                );
                if (range != null) {
                  setState(() {
                    _startDate = range.start;
                    _endDate = range.end;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, size: 18, color: AppColors.brandGreen),
                    const SizedBox(width: 12),
                    Text(
                      "${DateFormat('MMM dd, yyyy').format(_startDate)}  →  ${DateFormat('MMM dd, yyyy').format(_endDate)}",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Sitio Filter
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sitioFilter,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: "ALL SITIOS", child: Text("All Sitios")),
                    ...sitios.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (val) => setState(() => _sitioFilter = val!),
                ),
              ),
            ),
          ),
          // Gender Filter
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _genderFilter,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: "ALL GENDERS", child: Text("All Genders")),
                    DropdownMenuItem(value: "MALE", child: Text("Male")),
                    DropdownMenuItem(value: "FEMALE", child: Text("Female")),
                  ],
                  onChanged: (val) => setState(() => _genderFilter = val!),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _startDate = DateTime.now().subtract(const Duration(days: 30));
                _endDate = DateTime.now();
                _sitioFilter = "ALL SITIOS";
                _genderFilter = "ALL GENDERS";
              });
            },
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text("Reset"),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(List<VitalSigns> records, int residentCount) {
    final highRisk = records
        .where((r) =>
            r.status.toUpperCase().contains('HIGH') ||
            r.status.toUpperCase().contains('EMERGENCY'))
        .length;
    return Row(
      children: [
        _buildStatCard("Screenings in Range", records.length.toString(),
            Icons.analytics, Colors.blue),
        const SizedBox(width: 20),
        _buildStatCard("High Risk in Range", highRisk.toString(), Icons.warning,
            Colors.orange),
        const SizedBox(width: 20),
        _buildStatCard("Total Registered", residentCount.toString(), Icons.people,
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
          orElse: () => User.empty());
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
            child: sortedKeys.isEmpty 
            ? const Center(child: Text("No data for current filters"))
            : BarChart(
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
                        getTitlesWidget: (val, meta) {
                          if (val.toInt() >= sortedKeys.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(sortedKeys[val.toInt()].split(' ').last,
                                style: const TextStyle(fontSize: 10)),
                          );
                        },
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
          const Text("Detailed Screenings in Range",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          records.isEmpty 
          ? const Center(child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text("No data found for the current filter settings."),
          ))
          : Table(
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
                      child: Text("RESIDENT",
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
              ...records.reversed.take(50).map((r) {
                final user = users.firstWhere((u) => u.id == r.userId,
                    orElse: () => User.empty());
                return TableRow(
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(user.fullName)),
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child:
                            Text(DateFormat('MMM dd, yyyy').format(r.phtTimestamp))),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
}
