import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/admin_repository.dart';

class AdminAnnouncementsTab extends StatefulWidget {
  const AdminAnnouncementsTab({super.key});

  @override
  State<AdminAnnouncementsTab> createState() => _AdminAnnouncementsTabState();
}

class _AdminAnnouncementsTabState extends State<AdminAnnouncementsTab> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _selectedTarget = 'all';

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminRepo = context.watch<AdminRepository>();
    final announcements = adminRepo.announcements;

    return Row(
      children: [
        // Left Pane: Craft New Announcement
        Container(
          width: 450,
          color: Colors.white,
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Craft New Announcement",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Announcement Title",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          hintText: "Enter title...",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text("Target Audience",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(8)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedTarget,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                  value: 'all',
                                  child: Text("All Constituents")),
                              DropdownMenuItem(
                                  value: 'seniors',
                                  child: Text("Senior Citizens")),
                              DropdownMenuItem(
                                  value: 'children',
                                  child: Text("Parents of Children (0-5)")),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedTarget = val!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text("Announcement Body",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _contentController,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          hintText: "Type your full message here...",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Primary action: Post Announcement
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon:
                      const Icon(Icons.campaign, color: Colors.white, size: 20),
                  label: const Text("POST ANNOUNCEMENT",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    if (_titleController.text.isEmpty ||
                        _contentController.text.isEmpty) {
                      return;
                    }

                    final adminRepo = context.read<AdminRepository>();
                    await adminRepo.addAnnouncement(
                      title: _titleController.text,
                      content: _contentController.text,
                      targetGroup: _selectedTarget,
                    );

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Announcement Posted!"),
                      backgroundColor: AppColors.brandGreen,
                    ));
                    _titleController.clear();
                    _contentController.clear();
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Secondary action: Urgent Broadcast
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.warning_amber_rounded,
                      color: Colors.red.shade600, size: 20),
                  label: Text("URGENT BROADCAST",
                      style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade300, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    if (_titleController.text.isEmpty ||
                        _contentController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            "Title and Content must not be empty for broadcasts!"),
                        backgroundColor: Colors.red,
                      ));
                      return;
                    }

                    bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text("Confirm Broadcast")
                                ],
                              ),
                              content: const Text(
                                  "This will send a sticky red alert to EVERY registered patient's mobile app instantly. Are you sure?"),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("CANCEL")),
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text("SEND BROADCAST",
                                        style: TextStyle(color: Colors.white)))
                              ],
                            ));

                    if (confirm != true || !context.mounted) return;

                    final adminRepo = context.read<AdminRepository>();
                    await adminRepo.addAnnouncement(
                      title: "[URGENT] ${_titleController.text}",
                      content: _contentController.text,
                      targetGroup: 'BROADCAST_ALL',
                    );

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Urgent Broadcast Dispatched!"),
                      backgroundColor: Colors.red,
                    ));

                    _titleController.clear();
                    _contentController.clear();
                  },
                ),
              ),
            ],
          ),
        ),

        // Right Pane: Active Announcements
        Expanded(
            child: Container(
          color: Colors.grey[50],
          padding: const EdgeInsets.all(32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Active & Recent Announcements",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandDark)),
            const SizedBox(height: 24),
            Expanded(
                child: ListView.separated(
                    itemCount: announcements.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final ann = announcements[index];
                      return Card(
                          elevation: ann.isActive ? 2 : 0,
                          color: ann.isActive ? Colors.white : Colors.grey[200],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey[300]!)),
                          child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                  color: AppColors.brandDark
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          16)),
                                              child: Text(
                                                  ann.targetGroup
                                                      .toString()
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          AppColors.brandDark)),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                                DateFormat('MMM dd, yyyy')
                                                    .format(ann.phtTimestamp),
                                                style: const TextStyle(
                                                    color: Colors.grey)),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(ann.title,
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: ann.isActive
                                                    ? Colors.black
                                                    : Colors.grey)),
                                        const SizedBox(height: 8),
                                        Text(ann.content,
                                            style: TextStyle(
                                                color: ann.isActive
                                                    ? Colors.black87
                                                    : Colors.grey)),
                                      ],
                                    )),
                                    const SizedBox(width: 24),
                                    Column(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.red),
                                          onPressed: () async {
                                            final confirm =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text(
                                                    "Delete Announcement?"),
                                                content: const Text(
                                                    "This will permanently remove it for all users."),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              ctx, false),
                                                      child:
                                                          const Text("CANCEL")),
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              ctx, true),
                                                      child: const Text(
                                                          "DELETE",
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.red))),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              adminRepo
                                                  .deleteAnnouncement(ann.id);
                                            }
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        const Text("Status",
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12)),
                                        Switch(
                                          value: ann.isActive,
                                          activeThumbColor:
                                              AppColors.brandGreen,
                                          onChanged: (val) {
                                            adminRepo.toggleAnnouncementStatus(
                                                ann, val);
                                          },
                                        ),
                                        if (ann.reactions != null &&
                                            ann.reactions!.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            children:
                                                ann.reactions!.entries.map((e) {
                                              final count =
                                                  (e.value as List).length;
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text("${e.key} $count",
                                                    style: const TextStyle(
                                                        fontSize: 12)),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                        Text(
                                            ann.isActive
                                                ? "Active"
                                                : "Archived",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: ann.isActive
                                                    ? AppColors.brandGreen
                                                    : Colors.grey)),
                                      ],
                                    )
                                  ])));
                    }))
          ]),
        ))
      ],
    );
  }
}
