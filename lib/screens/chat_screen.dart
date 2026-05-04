import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../services/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../services/firebase_storage_service.dart';
import '../services/date_formatter.dart';

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
  bool _isUploading = false;
  bool _isTyping = false;
  late ChatProvider chatProvider;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chatProvider = context.read<ChatProvider>();
      chatProvider.fetchMessages(widget.user.id);
    });
  }

  void _onTextChanged() {
    final text = _messageController.text;
    if (text.isNotEmpty && !_isTyping) {
      setState(() => _isTyping = true);
      chatProvider.setTypingStatus(widget.user.id, true);
    } else if (text.isEmpty && _isTyping) {
      setState(() => _isTyping = false);
      chatProvider.setTypingStatus(widget.user.id, false);
    }
  }

  @override
  void dispose() {
    chatProvider.clearActiveChat();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    chatProvider.sendMessage(widget.user.id, text);
    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() => _isUploading = true);
        final String? imageUrl = await FirebaseStorageService.uploadImage(pickedFile.path);

        if (imageUrl != null) {
          await chatProvider.sendImageMessage(widget.user.id, imageUrl);
          _scrollToBottom();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () {}, // Show profile/info
          child: Row(
            children: [
              Hero(
                tag: widget.user.id,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: widget.user.profilePic != null && widget.user.profilePic!.isNotEmpty
                      ? CachedNetworkImageProvider(widget.user.profilePic!)
                      : null,
                  child: widget.user.profilePic == null || widget.user.profilePic!.isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Consumer<ChatProvider>(
                    builder: (context, provider, child) {
                      return Text(
                        provider.isPartnerTyping ? 'typing...' : 'Online',
                        style: TextStyle(
                          fontSize: 12,
                          color: provider.isPartnerTyping 
                            ? const Color(0xFF25D366) 
                            : Colors.white.withOpacity(0.8),
                          fontWeight: provider.isPartnerTyping ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B141B) : const Color(0xFFE5DDD5),
          image: DecorationImage(
            image: const AssetImage('assets/chat_bg.png'), // Add a placeholder pattern if available
            opacity: isDark ? 0.05 : 0.1,
            fit: BoxFit.cover,
            repeat: ImageRepeat.repeat,
          ),
        ),
        child: Column(
          children: [
            if (_isUploading)
              const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF25D366)),
              ),
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading && provider.messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = provider.messages;

                  if (messages.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Auto-scroll on new message
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      // With reverse: true, index 0 is the bottom of the list.
                      // We want latest messages at the bottom.
                      final message = messages[messages.length - 1 - index];
                      
                      final bool showDateHeader = index == messages.length - 1 ||
                          !_isSameDay(
                            messages[messages.length - 2 - index].timestamp, 
                            message.timestamp
                          );

                      return Column(
                        children: [
                          if (showDateHeader) _buildDateHeader(message.timestamp),
                          MessageBubble(message: message),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock, size: 32, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Messages are end-to-end encrypted. No one outside of this chat, not even MessageHub, can read or listen to them.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2C34) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            DateFormatter.formatTimestamp(date),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey[500]),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 5,
                      minLines: 1,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.attach_file, color: Colors.grey[500]),
                    onPressed: _pickImage,
                  ),
                  if (_messageController.text.isEmpty)
                    IconButton(
                      icon: Icon(Icons.camera_alt, color: Colors.grey[500]),
                      onPressed: _pickImage,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (context, value, child) {
              final isNotEmpty = value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: isNotEmpty ? _sendMessage : null,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: isNotEmpty 
                    ? Theme.of(context).colorScheme.secondary 
                    : (isDark ? Colors.grey[800] : Colors.grey[400]),
                  child: Icon(
                    isNotEmpty ? Icons.send : Icons.mic,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}