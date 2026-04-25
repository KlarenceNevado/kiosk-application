import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/domain/i_auth_repository.dart';
import '../../../auth/models/user_model.dart';
import '../../../chat/domain/i_chat_repository.dart';
import '../../../chat/models/chat_message.dart';

class AdminChatTab extends StatefulWidget {
  const AdminChatTab({super.key});

  @override
  State<AdminChatTab> createState() => _AdminChatTabState();
}

class _AdminChatTabState extends State<AdminChatTab> {
  User? _internalSelectedResident; // Keep for fallback but preferred via repository
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _replyingToId;
  String _searchQuery = "";
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onChatChanged);

    // With reverse: true, we don't need a repository listener for scrolling
    // because index 0 is always the bottom and stays pinned automatically.
    // But we might want it for other UI reactive elements if needed.
  }

  void _onChatChanged() {
    // Reverse list stays at index 0 automatically when new items are added
    if (!mounted || !_scrollController.hasClients) return;

    final bool isNearBottom = _scrollController.position.pixels <= 200;
    if (_showScrollToBottom == isNearBottom) {
      setState(() {
        _showScrollToBottom = !isNearBottom;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onChatChanged);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // Reversed list bottom is index 0
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatRepo = context.watch<IChatRepository>();
    final residents = context
        .watch<IAuthRepository>()
        .users
        .where((u) => u.parentId == null)
        .where((u) =>
            u.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            u.phoneNumber.contains(_searchQuery))
        .toList();

    // SORT BY LATEST MESSAGE
    residents.sort((a, b) {
      final timeA = chatRepo.getLatestMessageTime(a.id) ?? DateTime(1970);
      final timeB = chatRepo.getLatestMessageTime(b.id) ?? DateTime(1970);
      return timeB.compareTo(timeA);
    });

    final User? activeResident =
        chatRepo.selectedResident ?? _internalSelectedResident;

    return Row(
      children: [
        // RESIDENT LIST SIDEBAR
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search residents...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: residents.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final resident = residents[index];
                    final isSelected = activeResident?.id == resident.id;

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor:
                          AppColors.brandGreen.withValues(alpha: 0.1),
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? AppColors.brandGreen
                            : Colors.grey.shade200,
                        child: Icon(Icons.person,
                            color: isSelected ? Colors.white : Colors.grey),
                      ),
                      title: Text(resident.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      subtitle: Row(
                        children: [
                          Expanded(
                            child: Text(resident.phoneNumber,
                                style: const TextStyle(fontSize: 12)),
                          ),
                          if (chatRepo.getLatestMessageTime(resident.id) != null)
                            Text(
                              DateFormat('h:mm a').format(chatRepo
                                  .getLatestMessageTime(resident.id)!
                                  .toLocal()),
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (chatRepo.getUnreadCount(resident.id) > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                "${chatRepo.getUnreadCount(resident.id)}",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          const SizedBox(width: 4),
                          if (isSelected)
                            const Icon(Icons.chevron_right,
                                color: AppColors.brandGreen),
                        ],
                      ),
                      onTap: () {
                        chatRepo.setSelectedResident(resident);
                        setState(() {
                          _replyingToId = null;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // CHAT WINDOW
        Expanded(
          child: activeResident == null
              ? _buildUnselectedState()
              : Column(
                  children: [
                    _buildChatHeader(activeResident),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            color: Colors.grey.shade50,
                            child: ListView.builder(
                              controller: _scrollController,
                              reverse: true, // Latest at bottom (index 0)
                              padding: const EdgeInsets.all(32),
                              itemCount: chatRepo.messages.length,
                              itemBuilder: (context, index) {
                                final msg = chatRepo.messages[index];
                                final isMe = msg.senderId == 'admin';

                                // In a reversed list, "previous" in time is index + 1
                                final prevInTimeMsg =
                                    index < chatRepo.messages.length - 1
                                        ? chatRepo.messages[index + 1]
                                        : null;

                                final showDate = prevInTimeMsg == null ||
                                    DateFormat('yyyy-MM-dd')
                                            .format(msg.phtTimestamp) !=
                                        DateFormat('yyyy-MM-dd')
                                            .format(prevInTimeMsg.phtTimestamp);

                                return Column(
                                  children: [
                                    if (showDate)
                                      _buildDateHeader(msg.phtTimestamp),
                                    _buildMessageBubble(msg, isMe),
                                  ],
                                );
                              },
                            ),
                          ),
                          if (_showScrollToBottom)
                            Positioned(
                              right: 24,
                              bottom: 24,
                              child: FloatingActionButton.small(
                                onPressed: _scrollToBottom,
                                backgroundColor: AppColors.brandDark,
                                child: const Icon(Icons.arrow_downward,
                                    color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_replyingToId != null) _buildReplyPreview(chatRepo),
                    _buildMessageInput(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildUnselectedState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20),
              ],
            ),
            child: const Icon(Icons.forum_outlined,
                size: 80, color: AppColors.brandGreen),
          ),
          const SizedBox(height: 24),
          const Text("Select a resident to start chatting",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandDark)),
          const SizedBox(height: 8),
          const Text("Real-time support and coordination with residents.",
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildChatHeader(User activeResident) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.brandGreen.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: AppColors.brandGreen),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(activeResident.fullName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  CircleAvatar(
                      radius: 4,
                      backgroundColor: context
                                  .watch<IChatRepository>()
                                  .onlineStatus[activeResident.id] ==
                              true
                          ? AppColors.brandGreen
                          : Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                      context
                                  .watch<IChatRepository>()
                                  .onlineStatus[activeResident.id] ==
                              true
                          ? "Online"
                          : "Offline",
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Removed Call and More icons as requested
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          DateFormat('MMMM d, yyyy').format(date),
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.bold,
              letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    final repliedMsg = msg.replyTo != null
        ? context.read<IChatRepository>().messages.firstWhere(
            (m) => m.id == msg.replyTo,
            orElse: () => ChatMessage(
                id: '',
                senderId: '',
                receiverId: '',
                content: 'Message deleted',
                timestamp: DateTime.now(),
                updatedAt: DateTime.now()))
        : null;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.replyTo != null) _buildSmallReplyPreview(repliedMsg!, isMe),
            GestureDetector(
              onSecondaryTapDown: (details) =>
                  _showContextMenu(details.globalPosition, msg),
              onLongPress: () => _showOptions(msg),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.brandDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Text(
                  msg.content,
                  style: TextStyle(
                      color: isMe ? Colors.white : AppColors.brandDark,
                      fontSize: 16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                DateFormat('h:mm a').format(msg.phtTimestamp),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ),
            if (msg.reactions.isNotEmpty) _buildReactionRow(msg),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallReplyPreview(ChatMessage original, bool isMe) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 4),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
            left: BorderSide(color: AppColors.brandGreen, width: 4)),
      ),
      child: Text(
        original.content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
      ),
    );
  }

  Widget _buildReactionRow(ChatMessage msg) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: msg.reactions.entries.map((e) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.key, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text("${e.value.length}",
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReplyPreview(IChatRepository repo) {
    final msg = repo.messages.firstWhere((m) => m.id == _replyingToId!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, color: AppColors.brandGreen),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Replying to resident",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandGreen)),
                Text(msg.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _replyingToId = null),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          // Removed attachment icon as requested
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: "Write your response...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 20),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            height: 56,
            width: 56,
            child: ElevatedButton(
              onPressed: _sendMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final activeResident = context.read<IChatRepository>().selectedResident ??
        _internalSelectedResident;
    if (_messageController.text.trim().isEmpty || activeResident == null) {
      return;
    }

    final chatRepo = context.read<IChatRepository>();
    final message = ChatMessage(
      id: const Uuid().v4(),
      senderId: 'admin',
      receiverId: activeResident.id,
      content: _messageController.text.trim(),
      timestamp: DateTime.now(),
      replyTo: _replyingToId,
      updatedAt: DateTime.now(),
    );

    chatRepo.sendMessage(message);
    _messageController.clear();
    setState(() => _replyingToId = null);

    // No manual scroll needed with reverse: true!
    // It stays at 0 (bottom) if we're already there.
  }

  void _showOptions(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text("Reply"),
                onTap: () {
                  setState(() => _replyingToId = msg.id);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.forward_rounded),
                title: const Text("Forward"),
                onTap: () {
                  Navigator.pop(context);
                  _showForwardPicker(msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_reaction_outlined),
                title: const Text("React"),
                onTap: () {
                  Navigator.pop(context);
                  _showReactionPicker(msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title:
                    const Text("Delete", style: TextStyle(color: Colors.red)),
                onTap: () {
                  context.read<IChatRepository>().deleteMessage(msg.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showContextMenu(Offset position, ChatMessage msg) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          child: const Row(children: [
            Icon(Icons.reply),
            SizedBox(width: 12),
            Text("Reply")
          ]),
          onTap: () =>
              Future.microtask(() => setState(() => _replyingToId = msg.id)),
        ),
        PopupMenuItem(
          child: const Row(children: [
            Icon(Icons.forward),
            SizedBox(width: 12),
            Text("Forward")
          ]),
          onTap: () => _showForwardPicker(msg),
        ),
        PopupMenuItem(
          child: const Row(children: [
            Icon(Icons.add_reaction_outlined),
            SizedBox(width: 12),
            Text("React")
          ]),
          onTap: () => _showReactionPicker(msg),
        ),
        PopupMenuItem(
          child: const Row(children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 12),
            Text("Delete", style: TextStyle(color: Colors.red))
          ]),
          onTap: () => context.read<IChatRepository>().deleteMessage(msg.id),
        ),
      ],
    );
  }

  void _showReactionPicker(ChatMessage msg) {
    final emojis = ["❤️", "👍", "😂", "😮", "😢", "🔥"];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: emojis.map((emoji) {
              return GestureDetector(
                onTap: () {
                  context
                      .read<IChatRepository>()
                      .toggleReaction(msg.id, 'admin', emoji);
                  Navigator.pop(context);
                },
                child: Text(emoji, style: const TextStyle(fontSize: 32)),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showForwardPicker(ChatMessage msg) {
    final residents = context
        .read<IAuthRepository>()
        .users
        .where((u) => u.parentId == null)
        .toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text("Forward to...",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: residents.length,
                  itemBuilder: (context, index) {
                    final resident = residents[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(resident.fullName),
                      onTap: () {
                        context
                            .read<IChatRepository>()
                            .forwardMessage(msg, resident.id);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text("Message forwarded to ${resident.fullName}")));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
