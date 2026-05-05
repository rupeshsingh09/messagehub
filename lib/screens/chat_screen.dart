import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/user_model.dart';
import '../services/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../services/firebase_storage_service.dart';

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

  late ChatProvider chatProvider;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      chatProvider = context.read<ChatProvider>();
      chatProvider.fetchMessages(widget.user.id);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ================= SEND MESSAGE =================
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    chatProvider.sendMessage(widget.user.id, text);
    _messageController.clear();
    _scrollToBottom();
  }

  // ================= IMAGE =================
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() => _isUploading = true);

        final imageUrl =
        await FirebaseStorageService.uploadImage(pickedFile.path);

        if (imageUrl != null) {
          await chatProvider.sendImageMessage(widget.user.id, imageUrl);
          _scrollToBottom();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image upload failed')),
          );
        }
      }
    } catch (e) {
      debugPrint('Image error: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // ================= SCROLL =================
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[300],
              backgroundImage: widget.user.profilePic != null &&
                  widget.user.profilePic!.isNotEmpty
                  ? CachedNetworkImageProvider(widget.user.profilePic!)
                  : null,
              child: widget.user.profilePic == null ||
                  widget.user.profilePic!.isEmpty
                  ? const Icon(Icons.person, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(widget.user.name,
                style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),

      body: Column(
        children: [
          if (_isUploading) const LinearProgressIndicator(),

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
                    final message =
                    messages[messages.length - 1 - index];

                    return MessageBubble(message: message);
                  },
                );
              },
            ),
          ),

          _buildInputArea(),
        ],
      ),
    );
  }

  // ================= INPUT =================
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_emotions_outlined),

                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 5,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: _pickImage,
                  ),
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
                onTap: isNotEmpty ? _sendMessage : null,
                child: CircleAvatar(
                  backgroundColor:
                  isNotEmpty ? Colors.green : Colors.grey,
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