import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:swipe_to/swipe_to.dart';
import '../utils/date_formatter.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final ChatUser user;

  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  late ChatProvider chatProvider;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      chatProvider.fetchMessages(widget.user.id);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    chatProvider = Provider.of<ChatProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _typingTimer?.cancel();
    chatProvider.setCurrentChat(null);
    chatProvider.setMessageSearch('');
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    chatProvider.sendMessage(widget.user.id, text);
    _messageController.clear();
    chatProvider.sendTypingStatus(widget.user.id, false);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile != null) {
        await chatProvider.sendImageMessage(widget.user.id, pickedFile);
      }
    } catch (e) {
      debugPrint('Image error: $e');
    }
  }

  void _startRecording() async {
    debugPrint('[UI] 🎤 _startRecording triggered');
    await chatProvider.startRecording();
  }

  void _stopRecording() async {
    debugPrint('[UI] 🛑 _stopRecording triggered');
    final path = await chatProvider.stopRecording();
    debugPrint('[UI] 📍 _stopRecording path: $path');
    if (path != null) {
      await chatProvider.sendVoiceMessage(widget.user.id, path);
    }
  }

  void _onTyping(String val) {
    chatProvider.sendTypingStatus(widget.user.id, true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      chatProvider.sendTypingStatus(widget.user.id, false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildDefaultAppBar(),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const NetworkImage('https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png'), // Standard WhatsApp BG
            fit: BoxFit.cover,
            opacity: Theme.of(context).brightness == Brightness.dark ? 0.05 : 0.1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, provider, _) {
                  final messages = provider.messages;

                  if (provider.isLoading && messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (messages.isEmpty) {
                    return const Center(child: Text("No messages yet"));
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[messages.length - 1 - index];

                      return SwipeTo(
                        onRightSwipe: (details) {
                          provider.setReplyTo(message);
                        },
                        child: MessageBubble(
                          message: message,
                          onReply: () => provider.setReplyTo(message),
                          onDelete: (msg, forEveryone) { provider.deleteMessage(msg.id, forEveryone); },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            _buildReplyPreview(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  AppBar _buildDefaultAppBar() {
    return AppBar(
      titleSpacing: 0,
      title: Consumer<ChatProvider>(
        builder: (context, provider, _) {
          final isOnline = provider.onlineStatus[widget.user.id] ?? false;
          final lastSeen = provider.lastSeenTimes[widget.user.id];
          
          final latestUser = provider.users.firstWhere(
            (u) => u.id == widget.user.id, 
            orElse: () => widget.user
          );
          
          return InkWell(
            onTap: _showAccountDetails,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: latestUser.profilePic != null && latestUser.profilePic!.isNotEmpty
                      ? CachedNetworkImageProvider(ApiService.getImageUrl(latestUser.profilePic!))
                      : null,
                  child: latestUser.profilePic == null || latestUser.profilePic!.isEmpty
                      ? const Icon(Icons.person, size: 20)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(latestUser.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (provider.isPartnerTyping)
                        const Text('typing...', style: TextStyle(fontSize: 12, color: Colors.greenAccent))
                      else if (isOnline)
                        const Text('Online', style: TextStyle(fontSize: 12, color: Colors.white70))
                      else if (lastSeen != null)
                        Text('Last seen ${DateFormatter.formatLastSeen(lastSeen)}', 
                          style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video calling coming soon')),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.call),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Voice calling coming soon')),
            );
          },
        ),
        IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _isSearching = true)),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'clear': _showClearChatDialog(); break;
              case 'details': _showAccountDetails(); break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'details', child: Text('View Contact')),
            const PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
          ],
        ),
      ],
    );
  }

  AppBar _buildSearchAppBar() {
    return AppBar(
      leading: IconButton(icon: const Icon(Icons.close), onPressed: () {
        setState(() => _isSearching = false);
        _searchController.clear();
        chatProvider.setMessageSearch('');
      }),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Search messages...', border: InputBorder.none, hintStyle: TextStyle(color: Colors.white70)),
        style: const TextStyle(color: Colors.white),
        onChanged: (val) => chatProvider.setMessageSearch(val),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        if (provider.replyToMessage == null) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).cardColor.withOpacity(0.9),
          child: Row(
            children: [
              const Icon(Icons.reply, size: 20, color: Color(0xFF00A884)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(provider.replyToMessage!.isMe ? 'You' : 'Replied', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A884))),
                    Text(provider.replyToMessage!.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => provider.setReplyTo(null)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                      Expanded(
                        child: provider.isRecording
                            ? Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.mic, color: Colors.red, size: 16),
                                    const SizedBox(width: 8),
                                    const Text('Recording...',
                                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: const Duration(seconds: 1),
                                      builder: (context, value, child) =>
                                          Opacity(opacity: value, child: const Text('Release to send')),
                                      onEnd: () {},
                                    ),
                                  ],
                                ),
                              )
                            : TextField(
                                controller: _messageController,
                                maxLines: 5,
                                minLines: 1,
                                onChanged: _onTyping,
                                decoration: const InputDecoration(
                                  hintText: 'Message',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                ),
                              ),
                      ),
                      if (!provider.isRecording) ...[
                        IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.grey),
                          onPressed: () => _pickImage(ImageSource.camera),
                        ),
                        IconButton(
                          icon: const Icon(Icons.attach_file, color: Colors.grey),
                          onPressed: () => _pickImage(ImageSource.gallery),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _messageController,
                builder: (context, value, _) {
                  final isNotEmpty = value.text.trim().isNotEmpty;
                  return GestureDetector(
                    key: const ValueKey('mic_gesture_detector'),
                    onLongPressStart: !isNotEmpty ? (_) => _startRecording() : null,
                    onLongPressEnd: !isNotEmpty ? (_) => _stopRecording() : null,
                    onLongPressCancel: !isNotEmpty ? () => _stopRecording() : null,
                    onTap: isNotEmpty && !provider.isSendingMessage ? _sendMessage : null,
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: isNotEmpty && provider.isSendingMessage 
                          ? Colors.grey 
                          : const Color(0xFF00A884),
                      child: Icon(
                        isNotEmpty ? Icons.send : (provider.isRecording ? Icons.stop : Icons.mic),
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAccountDetails() {
     final provider = context.read<ChatProvider>();
     final latestUser = provider.users.firstWhere((u) => u.id == widget.user.id, orElse: () => widget.user);
     
     showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       builder: (_) => Container(
         padding: const EdgeInsets.symmetric(vertical: 20),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             CircleAvatar(
               radius: 60,
               backgroundImage: latestUser.profilePic != null && latestUser.profilePic!.isNotEmpty
                   ? CachedNetworkImageProvider(ApiService.getImageUrl(latestUser.profilePic!))
                   : null,
               child: latestUser.profilePic == null || latestUser.profilePic!.isEmpty
                   ? const Icon(Icons.person, size: 60)
                   : null,
             ),
             const SizedBox(height: 10),
             Text(latestUser.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
             Text(latestUser.phone, style: const TextStyle(fontSize: 16, color: Colors.grey)),
             const Divider(height: 30),
             ListTile(
               leading: const Icon(Icons.info_outline),
               title: const Text('About'),
               subtitle: Text(latestUser.bio),
             ),
           ],
         ),
       ),
     );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Delete all messages in this chat?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await chatProvider.clearChat(widget.user.id);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
