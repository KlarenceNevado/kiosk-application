import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/domain/i_auth_repository.dart';
import '../domain/i_chat_repository.dart';
import '../models/chat_message.dart';

class PatientChatScreen extends StatefulWidget {
  const PatientChatScreen({super.key});

  @override
  State<PatientChatScreen> createState() => _PatientChatScreenState();
}

class _PatientChatScreenState extends State<PatientChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _replyingToId;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<IAuthRepository>().currentUser;
      if (user != null) {
        // In the patient app, we're always chatting with the admin (system)
        final chatRepo = context.read<IChatRepository>();
        chatRepo.initChat(user.id, 'admin');

        // AUTO-SCROLL LISTENER
        chatRepo.addListener(_onChatChanged);

        // INITIAL SCROLL TO BOTTOM (reverse:true => position 0 is bottom)
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      }
    });
  }

  void _onChatChanged() {
    // With reverse: true, position 0 = bottom. Auto-scroll if near bottom.
    if (!mounted || !_scrollController.hasClients) return;

    final bool isNearBottom = _scrollController.position.pixels <= 200;
    if (isNearBottom) {
      // Auto-scroll to latest message
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
    if (_showScrollToBottom == isNearBottom) {
      setState(() {
        _showScrollToBottom = !isNearBottom;
      });
    }
  }

  @override
  void dispose() {
    try {
      context.read<IChatRepository>().removeListener(_onChatChanged);
    } catch (_) {}
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    // reverse:true => position 0 is bottom, higher values = scrolled up
    final bool isAtBottom = _scrollController.position.pixels <= 200;
    if (isAtBottom != !_showScrollToBottom) {
      setState(() {
        _showScrollToBottom = !isAtBottom;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // reverse:true => 0 is bottom
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final user = context.read<IAuthRepository>().currentUser;
    if (user == null) return;

    final chatRepo = context.read<IChatRepository>();
    final message = ChatMessage(
      id: const Uuid().v4(),
      senderId: user.id,
      receiverId: 'admin',
      content: _messageController.text.trim(),
      timestamp: DateTime.now(),
      replyTo: _replyingToId,
      updatedAt: DateTime.now(),
    );

    chatRepo.sendMessage(message);
    _messageController.clear();
    setState(() => _replyingToId = null);

    // Scroll to bottom (reverse:true => 0 is bottom)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatRepo = context.watch<IChatRepository>();
    final user = context.watch<IAuthRepository>().currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Health Center Inbox",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white)),
            Row(
              children: [
                CircleAvatar(
                    radius: 3,
                    backgroundColor: context
                                .watch<IChatRepository>()
                                .onlineStatus['admin'] ==
                            true
                        ? Colors.lightGreenAccent
                        : Colors.white54),
                const SizedBox(width: 4),
                Text(
                    context.watch<IChatRepository>().onlineStatus['admin'] ==
                            true
                        ? "Online"
                        : "Connecting...",
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        backgroundColor: AppColors.brandGreen,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {},
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                chatRepo.messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true, // Latest messages at bottom (index 0)
                        padding: const EdgeInsets.all(16),
                        itemCount: chatRepo.messages.length,
                        itemBuilder: (context, index) {
                          final msg = chatRepo.messages[index];
                          final isMe = msg.senderId == user?.id;

                          // In a reversed list, "previous" in time is index + 1
                          final prevInTimeMsg =
                              index < chatRepo.messages.length - 1
                                  ? chatRepo.messages[index + 1]
                                  : null;

                          // Show date if it's the first message ever (last index in reversed)
                          // or different from the message above it in the timeline (index + 1)
                          final showDate = prevInTimeMsg == null ||
                              DateFormat('yyyy-MM-dd')
                                      .format(msg.phtTimestamp) !=
                                  DateFormat('yyyy-MM-dd')
                                      .format(prevInTimeMsg.phtTimestamp);

                          return Column(
                            children: [
                              if (showDate) _buildDateHeader(msg.phtTimestamp),
                              _buildMessageBubble(msg, isMe),
                            ],
                          );
                        },
                      ),
                if (_showScrollToBottom)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      onPressed: _scrollToBottom,
                      backgroundColor: AppColors.brandGreen,
                      child:
                          const Icon(Icons.arrow_downward, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          if (_replyingToId != null) _buildReplyPreview(chatRepo),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            DateFormat('MMMM d, yyyy').format(date),
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No messages yet",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 18)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
                "Send a message to the Health Center for inquiries or health concerns.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    // Find the replied message if exists
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
        margin: const EdgeInsets.only(bottom: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.replyTo != null) _buildSmallReplyPreview(repliedMsg!, isMe),
            GestureDetector(
              onLongPress: () => _showOptions(msg),
              onDoubleTap: () => context.read<IChatRepository>().toggleReaction(
                  msg.id,
                  context.read<IAuthRepository>().currentUser!.id,
                  "❤️"),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.brandGreen : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  msg.content,
                  style: TextStyle(
                    color: isMe ? Colors.white : AppColors.brandDark,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (msg.reactions.isNotEmpty) _buildReactionRow(msg),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                DateFormat('h:mm a').format(msg.phtTimestamp),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallReplyPreview(ChatMessage original, bool isMe) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
            left: BorderSide(color: AppColors.brandGreen, width: 4)),
      ),
      child: Text(
        original.content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.key, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 2),
                Text("${e.value.length}",
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, color: AppColors.brandGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Replying to",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandGreen)),
                Text(msg.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() => _replyingToId = null),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.brandGreen,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
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
                  context.read<IChatRepository>().toggleReaction(msg.id,
                      context.read<IAuthRepository>().currentUser!.id, emoji);
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
    // For patients, they can forward to 'admin' (their only contact currently)
    // or maybe common family members? For now, let's keep it simple or allow forwarding back to admin.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Forward Message"),
        content: const Text("Forward this message to the Health Center?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              context.read<IChatRepository>().forwardMessage(msg, 'admin');
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Message forwarded")));
            },
            child: const Text("Forward"),
          ),
        ],
      ),
    );
  }
}
