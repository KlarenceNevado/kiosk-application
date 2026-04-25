import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/admin_repository.dart';
import '../../models/admin_models.dart';

class AdminBroadcastTab extends StatefulWidget {
  const AdminBroadcastTab({super.key});

  @override
  State<AdminBroadcastTab> createState() => _AdminBroadcastTabState();
}

class _AdminBroadcastTabState extends State<AdminBroadcastTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  String _selectedTarget = 'all_bhws';
  bool _isEmergency = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _contentController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TAB HEADER
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.brandGreen,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.brandGreen,
            tabs: const [
              Tab(text: "ANNOUNCEMENTS & ALERTS"),
              Tab(text: "AUTOMATED THRESHOLDS"),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBroadcastContent(),
              _buildThresholdsContent(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBroadcastContent() {
    final adminRepo = context.watch<AdminRepository>();
    
    return Row(
      children: [
        // Left: Create Form
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Create New Broadcast", 
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                _buildLabel("Broadcast Type"),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildTypeChip("Announcement", !_isEmergency),
                    _buildTypeChip("Emergency Alert", _isEmergency, isAlert: true),
                  ],
                ),
                const SizedBox(height: 24),
                _buildLabel("Target Audience"),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTarget,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'all_bhws', child: Text("All Active BHWs")),
                        DropdownMenuItem(value: 'patients', child: Text("All Residents")),
                        DropdownMenuItem(value: 'broadcast_all', child: Text("Global Broadcast (Everyone)")),
                      ],
                      onChanged: (val) => setState(() => _selectedTarget = val!),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildLabel("Headline / Title"),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: "Enter a brief headline...",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                _buildLabel("Message Content"),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText: "Enter the full message details here...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _handleSend,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    label: Text(_isEmergency ? "DISPATCH EMERGENCY ALERT" : "POST ANNOUNCEMENT", 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEmergency ? Colors.red : AppColors.brandGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right: Active Stream
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Active Communications", 
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Expanded(
                  child: RepaintBoundary(
                    child: ListView(
                      children: [
                        ...adminRepo.alerts.map((a) => _buildAlertCard(a, adminRepo)),
                        ...adminRepo.announcements.where((a) => !a.isArchived).map((a) => _buildAnnouncementCard(a, adminRepo)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String label, bool isSelected, {bool isAlert = false}) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _isEmergency = isAlert),
      selectedColor: isAlert ? Colors.red.withValues(alpha: 0.2) : AppColors.brandGreen.withValues(alpha: 0.2),
      checkmarkColor: isAlert ? Colors.red : AppColors.brandGreen,
      labelStyle: TextStyle(
        color: isSelected ? (isAlert ? Colors.red : AppColors.brandGreen) : Colors.grey,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
    );
  }

  Widget _buildAlertCard(SystemAlert alert, AdminRepository repo) {
    return Card(
      color: alert.isEmergency ? Colors.red[50] : Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: alert.isEmergency ? Colors.red.shade200 : Colors.grey.shade300),
      ),
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: alert.isEmergency ? Colors.red : Colors.orange),
        title: Text(alert.message, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Alert for ${alert.targetGroup} • ${DateFormat('MMM dd, hh:mm a').format(alert.phtTimestamp)}"),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => repo.deleteAlert(alert.id),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(Announcement ann, AdminRepository repo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.campaign, color: AppColors.brandGreen),
        title: Text(ann.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("To ${ann.targetGroup} • ${DateFormat('MMM dd').format(ann.timestamp)}"),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ann.content),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => repo.toggleAnnouncementArchive(ann, true),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text("Archive"),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => repo.deleteAnnouncement(ann.id),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text("Delete", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdsContent() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Automated Risk Thresholds", 
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text("The system automatically flags readings and notifies BHWs using intelligent clinical guidelines.",
            style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 48),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.health_and_safety, size: 40, color: Colors.blue.shade700),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Smart Clinical Algorithms Active", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                      SizedBox(height: 8),
                      Text(
                        "Risk thresholds are no longer statically configured. The system now automatically adjusts Heart Rate, Blood Pressure, SpO2, and BMI thresholds based on each resident's Age and Gender using World Health Organization (WHO) and American Heart Association (AHA) standards.\n\n"
                        "• Pediatric vitals are scaled automatically for infants, toddlers, and teens.\n"
                        "• Adult & Senior BP/HR thresholds adjust for baseline risk.\n"
                        "• SpO2 and Temperature use universal critical ranges.",
                        style: TextStyle(height: 1.5, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleSend() async {
    if (_contentController.text.isEmpty) return;
    
    final adminRepo = context.read<AdminRepository>();
    
    if (_isEmergency) {
      await adminRepo.addAlert(
        message: _contentController.text,
        targetGroup: _selectedTarget.toUpperCase(),
        isEmergency: true,
      );
    } else {
      await adminRepo.addAnnouncement(
        title: _titleController.text.isEmpty ? "Announcement" : _titleController.text,
        content: _contentController.text,
        targetGroup: _selectedTarget.toUpperCase(),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Broadcast sent successfully!"),
      backgroundColor: AppColors.brandGreen,
    ));
    
    _contentController.clear();
    _titleController.clear();
  }
}
