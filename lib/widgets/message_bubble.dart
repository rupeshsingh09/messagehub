import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '../utils/date_formatter.dart';
import '../services/api_service.dart';
import '../viewmodels/chat_viewmodel.dart';
import 'package:photo_view/photo_view.dart';
import 'package:audioplayers/audioplayers.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onReply;
  final Function(Message, bool)? onDelete;

  const MessageBubble({
    super.key, 
    required this.message, 
    this.onReply,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final myBubbleColor = isDark ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB);
    final otherBubbleColor = isDark ? const Color(0xFF1F2C34) : Colors.white;
    final textColor = isDark ? Colors.white.withOpacity(0.9) : Colors.black87;
    final timeColor = isDark ? Colors.white54 : Colors.black45;

    return GestureDetector(
      onLongPress: () => _showOptions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Align(
          alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                decoration: BoxDecoration(
                  color: message.isMe ? myBubbleColor : otherBubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: message.isMe ? const Radius.circular(12) : const Radius.circular(0),
                    bottomRight: message.isMe ? const Radius.circular(0) : const Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reply Preview
                    if (message.replyToId != null)
                      _buildReplyPreview(context, isDark),
                    
                    // Image Message
                    if (message.type == MessageType.image && message.imageUrl != null)
                      _buildImageMessage(context, isDark),
                    
                    // Audio Message
                    if (message.type == MessageType.audio && message.audioUrl != null)
                      _buildAudioMessage(context, isDark),

                    // Text Message
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.isDeleted)
                            Text(
                              '🚫 This message was deleted',
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: textColor.withOpacity(0.6),
                              ),
                            )
                          else if (message.text.isNotEmpty && message.type == MessageType.text)
                            Text(
                              message.text,
                              style: TextStyle(
                                fontSize: 16,
                                color: textColor,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Spacer(),
                              Text(
                                DateFormatter.formatMessageTime(message.timestamp),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: timeColor,
                                ),
                              ),
                              if (message.isMe && !message.isDeleted) ...[
                                const SizedBox(width: 4),
                                _buildStatusIcon(isDark),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool isDark) {
    IconData icon = Icons.done;
    Color color = isDark ? Colors.white54 : Colors.black38;

    if (message.status == MessageStatus.delivered) {
      icon = Icons.done_all;
    } else if (message.status == MessageStatus.seen) {
      icon = Icons.done_all;
      color = const Color(0xFF53BDEB); // WhatsApp Blue check
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _buildReplyPreview(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: message.isMe ? const Color(0xFF00A884) : Colors.blue,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.isMe ? 'You' : 'Replied',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: message.isMe ? const Color(0xFF00A884) : Colors.blue,
            ),
          ),
          Text(
            message.replyText ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => _viewFullScreenImage(context),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: CachedNetworkImage(
          imageUrl: ApiService.getImageUrl(message.imageUrl!),
          placeholder: (context, url) => Container(
            height: 200,
            width: double.infinity,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => Container(
            height: 200,
            width: double.infinity,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildAudioMessage(context, bool isDark) {
    return AudioBubble(
      audioUrl: ApiService.getImageUrl(message.audioUrl!),
      isMe: message.isMe,
    );
  }

  void _viewFullScreenImage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
          body: Center(
            child: PhotoView(
              imageProvider: CachedNetworkImageProvider(ApiService.getImageUrl(message.imageUrl!)),
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFF00A884)),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                if (onReply != null) onReply!();
              },
            ),
            if (!message.isDeleted) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.grey),
                title: const Text('Delete for Me'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (onDelete != null) onDelete!(message, false);
                  // Default in ChatScreen is forEveryone: true, 
                  // but we should pass false here. 
                  // Wait, ChatScreen's onDelete calls provider.deleteMessage(msg.id, true).
                  // I should probably handle this in ChatScreen by passing the forEveryone flag.
                },
              ),
              if (message.isMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete for Everyone'),
                  onTap: () {
                    Navigator.pop(ctx);
                    // This will be handled in ChatScreen's onDelete callback
                    if (onDelete != null) onDelete!(message, true);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class AudioBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  const AudioBubble({super.key, required this.audioUrl, required this.isMe});

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.isMe ? Colors.white : const Color(0xFF00A884);
    final iconColor = widget.isMe ? Colors.white70 : Colors.grey;

    return Container(
      width: MediaQuery.of(context).size.width * 0.65,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () async {
              if (_isPlaying) {
                await _player.pause();
              } else {
                await _player.play(UrlSource(widget.audioUrl));
              }
              if (mounted) setState(() => _isPlaying = !_isPlaying);
            },
            child: CircleAvatar(
              radius: 22,
              backgroundColor: widget.isMe ? Colors.black12 : const Color(0xFF00A884).withOpacity(0.1),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isMe ? Colors.white : const Color(0xFF00A884),
                size: 30,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                    activeTrackColor: widget.isMe ? Colors.white : const Color(0xFF00A884),
                    inactiveTrackColor: widget.isMe ? Colors.white30 : Colors.grey.withOpacity(0.3),
                    thumbColor: widget.isMe ? Colors.white : const Color(0xFF00A884),
                    overlayColor: (widget.isMe ? Colors.white : const Color(0xFF00A884)).withOpacity(0.2),
                  ),
                  child: Slider(
                    value: _position.inSeconds.toDouble(),
                    max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                    onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(fontSize: 11, color: widget.isMe ? Colors.white70 : Colors.grey[600]),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(fontSize: 11, color: widget.isMe ? Colors.white70 : Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8, left: 4),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: widget.isMe ? Colors.white24 : Colors.grey[200],
                  child: Icon(
                    Icons.person,
                    color: widget.isMe ? Colors.white : Colors.grey[400],
                    size: 20,
                  ),
                ),
              ),
              const Positioned(
                bottom: 0,
                right: 6,
                child: Icon(
                  Icons.mic,
                  color: Color(0xFF00A884),
                  size: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
