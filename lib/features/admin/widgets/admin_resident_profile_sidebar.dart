import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../auth/domain/i_auth_repository.dart';
import '../../auth/models/user_model.dart';
import '../../chat/domain/i_chat_repository.dart';
import '../../health_check/models/vital_signs_model.dart';
import 'dart:math' as math;

class AdminResidentProfileSidebar extends StatefulWidget {
  final User resident;
  final List<VitalSigns> residentRecords;
  final VoidCallback? onMessagePressed;

  const AdminResidentProfileSidebar({
    super.key,
    required this.resident,
    required this.residentRecords,
    this.onMessagePressed,
  });

  @override
  State<AdminResidentProfileSidebar> createState() =>
      _AdminResidentProfileSidebarState();
}

class _AdminResidentProfileSidebarState
    extends State<AdminResidentProfileSidebar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<IChatRepository>().initChat('admin', widget.resident.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sort records descending for the list/stats
    final records = List<VitalSigns>.from(widget.residentRecords)
      ..sort((a, b) => b.phtTimestamp.compareTo(a.phtTimestamp));

    // Calculate Average BMI
    double avgBmi = 0.0;
    if (records.isNotEmpty) {
      double totalBmi = 0.0;
      int bmiCount = 0;
      for (var r in records) {
        if (r.bmi != null) {
          totalBmi += r.bmi!;
          bmiCount++;
        }
      }
      if (bmiCount > 0) avgBmi = totalBmi / bmiCount;
    }

    final chatRepo = context.watch<IChatRepository>();
    final messages = chatRepo.messages
        .where((m) =>
            m.senderId == widget.resident.id ||
            m.receiverId == widget.resident.id)
        .toList();
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // newest first

    return Container(
      width: 500, // Sidebar width
      height: MediaQuery.of(context).size.height,
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.brandDark,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.brandGreen,
                  child: Icon(Icons.person, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.resident.fullName,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text(
                          "${widget.resident.phoneNumber} • ${widget.resident.gender}",
                          style: TextStyle(
                              color: Colors.grey.shade300, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: DefaultTabController(
              length: 4,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI ROW
                    Row(
                      children: [
                        _buildMiniKpiCard("Total Visits", "${records.length}",
                            Icons.assignment_turned_in, Colors.blue),
                        const SizedBox(width: 16),
                        _buildMiniKpiCard(
                            "Avg BMI",
                            avgBmi > 0 ? avgBmi.toStringAsFixed(1) : "--",
                            Icons.accessibility_new,
                            AppColors.brandGreen),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // HEALTH WORKER ASSIGNMENT
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.medical_services, size: 16, color: AppColors.brandGreen),
                              SizedBox(width: 8),
                              Text("Assigned Health Worker",
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.brandDark)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.resident.assignedBhwName ?? "No Health Worker Assigned",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: widget.resident.assignedBhwId != null 
                                        ? AppColors.brandDark 
                                        : Colors.grey,
                                    fontWeight: widget.resident.assignedBhwId != null 
                                        ? FontWeight.w500 
                                        : FontWeight.normal
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _showBhwAssignmentDialog(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(widget.resident.assignedBhwId == null ? "ASSIGN" : "CHANGE"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // TABBED CHARTS
                    const Text("Vital Sign Trends (6-Month)",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandDark)),
                    const SizedBox(height: 16),
                    Container(
                      height: 400,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        children: [
                          const TabBar(
                            labelColor: AppColors.brandDark,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: AppColors.brandGreen,
                            isScrollable: true,
                            tabs: [
                              Tab(text: "BP"),
                              Tab(text: "Heart Rate"),
                              Tab(text: "SpO2"),
                              Tab(text: "Temp"),
                            ],
                          ),
                          Expanded(
                            child: RepaintBoundary(
                              child: TabBarView(
                                children: [
                                  _buildBloodPressureChart(),
                                  _buildUniversalChart("Heart Rate",
                                      (v) => v.heartRate, Colors.red.shade400,
                                      multiple: 10, padding: 20),
                                  _buildUniversalChart("SpO2 Level (%)",
                                      (v) => v.oxygen, Colors.blue.shade400,
                                      multiple: 2, padding: 5),
                                  _buildUniversalChart(
                                      "Temperature (°C)",
                                      (v) => v.temperature,
                                      Colors.orange.shade400,
                                      multiple: 1,
                                      padding: 1),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // INBOX HISTORY
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Inbox History",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brandDark)),
                        TextButton.icon(
                            onPressed: () {
                              context
                                  .read<IChatRepository>()
                                  .setSelectedResident(widget.resident);
                              widget.onMessagePressed?.call();
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.message, size: 18),
                            label: const Text("Message Resident"))
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (messages.isEmpty)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.mark_email_read,
                                    size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Text(
                                    "No direct messages sent to ${widget.resident.firstName} yet.",
                                    style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: messages.length > 5 ? 5 : messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isAdminMsg = msg.senderId == 'admin';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: isAdminMsg
                                  ? AppColors.brandDark
                                  : AppColors.brandGreen,
                              child: Icon(
                                  isAdminMsg
                                      ? Icons.admin_panel_settings
                                      : Icons.person,
                                  color: Colors.white,
                                  size: 18),
                            ),
                            title: Text(msg.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: Text(
                              _formatTime(msg.phtTimestamp),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          );
                        },
                      )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    if (time.day == DateTime.now().day &&
        time.month == DateTime.now().month &&
        time.year == DateTime.now().year) {
      return "Today at ${time.hour}:${time.minute.toString().padLeft(2, '0')}";
    }
    return "${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}/${time.year}";
  }

  Widget _buildMiniKpiCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDark)),
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodPressureChart() {
    if (widget.residentRecords.length < 2) {
      return const Center(
          child: Text("Requires at least 2 visits to generate a trend line.",
              style: TextStyle(color: Colors.grey)));
    }

    final chartData = List<VitalSigns>.from(widget.residentRecords)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    int getMinY() {
      int minDiastolic = chartData.map((e) => e.diastolicBP).reduce(math.min);
      return (minDiastolic / 10).floor() * 10 - 20;
    }

    int getMaxY() {
      int maxSystolic = chartData.map((e) => e.systolicBP).reduce(math.max);
      return (maxSystolic / 10).ceil() * 10 + 20;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 24, top: 32, bottom: 24, left: 16),
      child: LineChart(
        LineChartData(
            minY: getMinY().toDouble(),
            maxY: getMaxY().toDouble(),
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        value.toStringAsFixed(0),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 10),
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    if (index < 0 || index >= chartData.length) {
                      return const SizedBox.shrink();
                    }
                    final date = chartData[index].phtTimestamp;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text("${date.month}/${date.day}",
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 10)),
                    );
                  },
                  interval: 1,
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: chartData
                    .asMap()
                    .entries
                    .map((e) =>
                        FlSpot(e.key.toDouble(), e.value.systolicBP.toDouble()))
                    .toList(),
                isCurved: true,
                color: Colors.red.shade400,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(show: false),
              ),
              LineChartBarData(
                spots: chartData
                    .asMap()
                    .entries
                    .map((e) => FlSpot(
                        e.key.toDouble(), e.value.diastolicBP.toDouble()))
                    .toList(),
                isCurved: true,
                color: Colors.blue.shade400,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(show: false),
              )
            ],
            lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots
                          .map((spot) => LineTooltipItem(
                              "${spot.y.toInt()}",
                              const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)))
                          .toList();
                    }))),
      ),
    );
  }

  Widget _buildUniversalChart(
      String title, num Function(VitalSigns) selector, Color color,
      {required int multiple, required int padding}) {
    if (widget.residentRecords.length < 2) {
      return const Center(
          child: Text("Requires at least 2 visits to generate a trend line.",
              style: TextStyle(color: Colors.grey)));
    }

    final chartData = List<VitalSigns>.from(widget.residentRecords)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    int minY = chartData.isEmpty
        ? 0
        : (chartData.map(selector).reduce(math.min) / multiple).floor() *
                multiple -
            padding;
    int maxY = chartData.isEmpty
        ? 100
        : (chartData.map(selector).reduce(math.max) / multiple).ceil() *
                multiple +
            padding;

    return Padding(
      padding: const EdgeInsets.only(right: 24, top: 32, bottom: 24, left: 16),
      child: LineChart(
        LineChartData(
          minY: minY.toDouble(),
          maxY: maxY.toDouble(),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      value.toStringAsFixed(0),
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index < 0 || index >= chartData.length) {
                    return const SizedBox.shrink();
                  }
                  final date = chartData[index].phtTimestamp;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text("${date.month}/${date.day}",
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 10)),
                  );
                },
                interval: 1,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: chartData
                  .asMap()
                  .entries
                  .map((e) =>
                      FlSpot(e.key.toDouble(), selector(e.value).toDouble()))
                  .toList(),
              isCurved: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            )
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots
                    .map((spot) => LineTooltipItem(
                        "${(spot.y % 1 == 0) ? spot.y.toInt() : spot.y.toStringAsFixed(1)}",
                        const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)))
                    .toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showBhwAssignmentDialog(BuildContext context) {
    final authRepo = context.read<IAuthRepository>();
    final List<User> staff = authRepo.users
        .where((u) => u.role == 'bhw' || u.role == 'admin')
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Assign Health Worker",
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandDark)),
        content: SizedBox(
          width: 400,
          child: staff.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text("No health workers or staff found in the system.",
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: staff.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final worker = staff[index];
                    final isCurrent = worker.id == widget.resident.assignedBhwId;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCurrent ? AppColors.brandGreen : Colors.grey.shade200,
                        child: Icon(Icons.person, color: isCurrent ? Colors.white : Colors.grey),
                      ),
                      title: Text(worker.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(worker.role.toUpperCase(), style: const TextStyle(fontSize: 12)),
                      trailing: isCurrent 
                        ? const Icon(Icons.check_circle, color: AppColors.brandGreen)
                        : const Icon(Icons.chevron_right, size: 16),
                      onTap: () {
                        authRepo.assignHealthWorker(
                          residentId: widget.resident.id,
                          bhwId: worker.id,
                          bhwName: worker.fullName,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("Resident successfully assigned to ${worker.fullName}"),
                          backgroundColor: AppColors.brandGreen,
                        ));
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
        ],
      ),
    );
  }
}
