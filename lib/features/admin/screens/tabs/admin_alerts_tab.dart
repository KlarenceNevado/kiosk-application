import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/admin_repository.dart';
import '../../models/admin_models.dart';

class AdminAlertsTab extends StatefulWidget {
  const AdminAlertsTab({super.key});

  @override
  State<AdminAlertsTab> createState() => _AdminAlertsTabState();
}

class _AdminAlertsTabState extends State<AdminAlertsTab> {
  final TextEditingController _msgController = TextEditingController();
  String _selectedTarget = 'all_bhws';
  bool _isEmergency = false;

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminRepo = context.watch<AdminRepository>();
    final alerts = adminRepo.alerts;
    return Column(
      children: [
        // TOP SECTION: Dispatch and Active Alerts
        Expanded(
            flex: 3,
            child: Row(children: [
              // LEFT: Dispatch
              Expanded(
                  child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(32),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Dispatch System Alert",
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Target Group",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey[300]!),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedTarget,
                                          isExpanded: true,
                                          items: const [
                                            DropdownMenuItem(
                                                value: 'all_bhws',
                                                child: Text("All Active BHWs")),
                                            DropdownMenuItem(
                                                value: 'patients',
                                                child: Text("All Patients")),
                                            DropdownMenuItem(
                                                value: 'broadcast_all',
                                                child: Text(
                                                    "Broadast to All (Global)")),
                                            DropdownMenuItem(
                                                value: 'leads',
                                                child: Text(
                                                    "BHW Coordinators / Leads")),
                                            DropdownMenuItem(
                                                value: 'sitio_2',
                                                child:
                                                    Text("Sitio 2 BHW Team")),
                                          ],
                                          onChanged: (val) => setState(
                                              () => _selectedTarget = val!),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text("Alert Message",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _msgController,
                                      maxLines: 3,
                                      decoration: const InputDecoration(
                                        hintText:
                                            "Enter urgent alert or instruction...",
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(children: [
                                      Switch(
                                          value: _isEmergency,
                                          activeThumbColor: Colors.red,
                                          onChanged: (val) => setState(
                                              () => _isEmergency = val)),
                                      const SizedBox(width: 8),
                                      Text("Mark as Critical Emergency",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _isEmergency
                                                  ? Colors.red
                                                  : Colors.grey)),
                                    ]),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                    icon: const Icon(Icons.send_rounded,
                                        color: Colors.white),
                                    label: const Text("SEND ALERT",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: _isEmergency
                                            ? Colors.red
                                            : AppColors.brandGreen),
                                    onPressed: () async {
                                      if (_msgController.text.isEmpty) return;

                                      final adminRepo =
                                          context.read<AdminRepository>();
                                      await adminRepo.addAlert(
                                        message: _msgController.text,
                                        targetGroup:
                                            _selectedTarget.toUpperCase(),
                                        isEmergency: _isEmergency,
                                      );

                                      if (!context.mounted) return;

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  "Alert Dispatched Successfully"),
                                              backgroundColor:
                                                  AppColors.brandGreen));
                                      _msgController.clear();
                                      setState(() {
                                        _isEmergency = false;
                                        _selectedTarget = 'all_bhws';
                                      });
                                    }))
                          ]))),

              // RIGHT: Recent Alerts
              Expanded(
                child: Container(
                  color: Colors.grey[50],
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Community Alerts",
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandDark)),
                      const SizedBox(height: 24),
                      Expanded(
                        child: _buildAlertsList(alerts, adminRepo),
                      )
                    ],
                  ),
                ),
              )
            ])),

        // BOTTOM SECTION: Automated Config
        Container(
            height: 250,
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[300]!))),
            padding: const EdgeInsets.all(32),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Automated Alert Thresholds",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  "Automatically flag readings and notify BHWs if vitals exceed these bounds.",
                  style: TextStyle(color: Colors.grey)),
              const Spacer(),
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          "Systolic High Bound: ${adminRepo.sysHigh.toInt()} mmHg",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Slider(
                        value: adminRepo.sysHigh,
                        min: 120,
                        max: 200,
                        divisions: 80,
                        activeColor: Colors.red,
                        onChanged: (val) =>
                            adminRepo.updateThresholds(sysHigh: val),
                      )
                    ])),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          "Systolic Low Bound: ${adminRepo.sysLow.toInt()} mmHg",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Slider(
                        value: adminRepo.sysLow,
                        min: 60,
                        max: 110,
                        divisions: 50,
                        activeColor: Colors.orange,
                        onChanged: (val) =>
                            adminRepo.updateThresholds(sysLow: val),
                      )
                    ])),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          "Heart Rate High Bound: ${adminRepo.hrHigh.toInt()} bpm",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Slider(
                        value: adminRepo.hrHigh,
                        min: 80,
                        max: 150,
                        divisions: 70,
                        activeColor: Colors.red,
                        onChanged: (val) =>
                            adminRepo.updateThresholds(hrHigh: val),
                      )
                    ]))
              ])
            ]))
      ],
    );
  }

  Widget _buildAlertsList(List<SystemAlert> alerts, AdminRepository adminRepo) {
    if (alerts.isEmpty) {
      return const Center(child: Text("No alerts found in this category."));
    }

    return ListView.builder(
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          return Card(
              color: alert.isEmergency ? Colors.red[50] : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: alert.isEmergency
                          ? Colors.red[200]!
                          : Colors.grey[300]!)),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: alert.isEmergency
                                          ? Colors.red
                                          : AppColors.brandDark,
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text(alert.targetGroup,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                              Row(
                                children: [
                                  Text(
                                      DateFormat('MMM dd, hh:mm a')
                                          .format(alert.phtTimestamp),
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert,
                                        color: Colors.grey, size: 20),
                                    onSelected: (val) {
                                      if (val == 'delete') {
                                        _confirmDeleteAlert(
                                            context, alert, adminRepo);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Permanently Delete',
                                              style: TextStyle(
                                                  color: Colors.red))),
                                    ],
                                  ),
                                ],
                              ),
                            ]),
                        const SizedBox(height: 12),
                        Text(alert.message,
                            style: const TextStyle(fontSize: 16)),
                      ])));
        });
  }

  void _confirmDeleteAlert(
      BuildContext context, SystemAlert alert, AdminRepository repo) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Delete Alert"),
              content: const Text(
                  "Are you sure you want to permanently delete this alert? This action cannot be undone."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel")),
                ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      repo.deleteAlert(alert.id);
                      Navigator.pop(ctx);
                    },
                    child: const Text("Delete",
                        style: TextStyle(color: Colors.white))),
              ],
            ));
  }
}
