import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/date_formatter.dart';

class UserTile extends StatelessWidget {
  final ChatUser user;
  final VoidCallback onTap;

  const UserTile({
    super.key,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
        backgroundImage: user.profilePic != null && user.profilePic!.isNotEmpty
            ? CachedNetworkImageProvider(user.profilePic!)
            : null,
        child: user.profilePic == null || user.profilePic!.isEmpty
            ? Icon(Icons.person, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 30)
            : null,
      ),
      title: Text(
        user.name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        user.lastMessage ?? 'Tap to start chatting',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          fontSize: 14,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (user.lastMessageTime != null)
            Text(
              DateFormatter.formatTimestamp(user.lastMessageTime!),
              style: TextStyle(
                fontSize: 12,
                color: user.unreadCount > 0 
                  ? const Color(0xFF25D366) 
                  : (isDark ? Colors.grey[500] : Colors.grey[600]),
              ),
            ),
          const SizedBox(height: 5),
          if (user.unreadCount > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF25D366),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${user.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
