import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/domain/i_system_repository.dart';
import 'package:provider/provider.dart';
import '../../auth/domain/i_auth_repository.dart';

class PatientAnnouncementsScreen extends StatefulWidget {
  const PatientAnnouncementsScreen({super.key});

  @override
  State<PatientAnnouncementsScreen> createState() =>
      _PatientAnnouncementsScreenState();
}

class _PatientAnnouncementsScreenState
    extends State<PatientAnnouncementsScreen> {
  List<Map<String, dynamic>>? _initialData;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final systemRepo = context.read<ISystemRepository>();
      final authRepo = context.read<IAuthRepository>();
      final data = await systemRepo.fetchAnnouncements(currentUser: authRepo.currentUser);
      if (mounted) {
        setState(() {
          _initialData = data;
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = context.watch<IAuthRepository>();
    final systemRepo = context.read<ISystemRepository>();
    final user = authRepo.currentUser;

    if (_isInitialLoading && _initialData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text("Announcements",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.brandGreen,
          elevation: 0,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.brandGreen)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Announcements",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.brandGreen,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: systemRepo.announcementStream,
        initialData: _initialData,
        builder: (context, snapshot) {
          // If we have data (from initialData or Stream), show it.
          // ConnectionState.waiting should only show a spinner if we have NO data yet.
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.brandGreen));
          }

          if (snapshot.hasError) {
             return Center(
               child: Padding(
                 padding: const EdgeInsets.all(32.0),
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.redAccent),
                     const SizedBox(height: 16),
                     Text(
                       snapshot.error.toString().contains('RealtimeSubscribeException') 
                           ? "Connection Lost" 
                           : "Something went wrong",
                       style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                     ),
                     const SizedBox(height: 8),
                     const Text(
                       "We're having trouble reaching the server. Please try refreshing.",
                       textAlign: TextAlign.center,
                       style: TextStyle(color: Colors.grey),
                     ),
                     const SizedBox(height: 24),
                     ElevatedButton.icon(
                       onPressed: () {
                         // A simple setState will trigger a rebuild and re-subscribe
                         setState(() {});
                       },
                       icon: const Icon(Icons.refresh),
                       label: const Text("Retry Connection"),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: AppColors.brandGreen,
                         foregroundColor: Colors.white,
                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                     ),
                   ],
                 ),
               ),
             );
          }

          final rawData = snapshot.data ?? [];
          
          // Strict filtering for Active and Not Deleted
          var announcements = rawData.where((a) {
            final isActive = a['is_active'] == 1 || a['is_active'] == true || a['isActive'] == 1 || a['isActive'] == true;
            final isDeleted = a['is_deleted'] == 1 || a['is_deleted'] == true;
            return isActive && !isDeleted;
          }).toList();
          
          // User-specific filtering (Seniors/Children/All)
          if (user != null) {
            final int age = user.age;
            announcements = announcements.where((a) {
              final target = (a['target_group'] ?? a['targetGroup'])?.toString().toUpperCase() ?? 'ALL';
              if (target == 'ALL' || target == 'BROADCAST_ALL') return true;
              if (target == 'SENIORS' && age >= 60) return true;
              if (target == 'CHILDREN' && age <= 12) return true;
              return false;
            }).toList();
          }

          if (announcements.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => systemRepo.syncNow(authRepo: authRepo),
              child: Stack(
                children: [
                   ListView(), // For pull-to-refresh
                   Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign_outlined,
                            color: Colors.grey.shade300, size: 80),
                        const SizedBox(height: 16),
                        const Text("No announcements yet",
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                          child: Text(
                            "Important updates from your Barangay will appear here.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => systemRepo.syncNow(authRepo: authRepo),
            color: AppColors.brandGreen,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: announcements.length,
              itemBuilder: (context, index) {
                return _buildAnnouncementCard(announcements[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> item) {
    final title = item['title'] ?? 'Announcement';
    final content = item['content'] ?? '';
    final timestamp =
        DateTime.tryParse(item['timestamp'] ?? '') ?? DateTime.now();
    final isUrgent =
        (item['targetGroup'] ?? item['target_group']) == 'BROADCAST_ALL';
    final formatter = DateFormat('MMMM d, yyyy • h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isUrgent ? Colors.red.shade600 : AppColors.brandGreen,
              child: Row(
                children: [
                  Icon(
                    isUrgent ? Icons.warning_rounded : Icons.campaign_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isUrgent ? "URGENT BROADCAST" : "BARANGAY UPDATE",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        formatter.format(timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildReactionsDisplay(item),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionsDisplay(Map<String, dynamic> item) {
    final reactions = item['reactions'] as Map<String, dynamic>? ?? {};
    if (reactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 16),
        child: InkWell(
          onTap: () => _showReactionPicker(item['id']),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_reaction_outlined,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text("React",
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      child: Wrap(
        spacing: 8,
        children: [
          ...reactions.entries.map((entry) {
            final count = (entry.value as List).length;
            return InkWell(
              onTap: () => _onReactionToggle(item['id'], entry.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.brandGreen.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.key, style: const TextStyle(fontSize: 14)),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Text(count.toString(),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandGreen)),
                    ],
                  ],
                ),
              ),
            );
          }),
          InkWell(
            onTap: () => _showReactionPicker(item['id']),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100, shape: BoxShape.circle),
              child: Icon(Icons.add, size: 20, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  void _showReactionPicker(String id) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['👍', '❤️', '🙌', '🙏', '📢', '✅'].map((emoji) {
                return InkWell(
                  onTap: () {
                    _onReactionToggle(id, emoji);
                    Navigator.pop(context);
                  },
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _onReactionToggle(String id, String emoji) {
    final authRepo = context.read<IAuthRepository>();
    final systemRepo = context.read<ISystemRepository>();
    final user = authRepo.currentUser;
    if (user != null) {
      systemRepo.reactToAnnouncement(id, emoji, user.id);
    }
  }

}
