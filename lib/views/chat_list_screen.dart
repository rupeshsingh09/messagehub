import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/user_model.dart';
import '../providers/chat_provider.dart';
import '../viewmodels/theme_viewmodel.dart';
import '../utils/date_formatter.dart';
import '../services/api_service.dart';

import '../views/chat_screen.dart';
import '../views/login_screen.dart';
import '../views/signup_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    await context.read<ChatProvider>().fetchContactsAndMatch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeViewModel>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildDefaultAppBar(themeProvider),
      body: Consumer<ChatProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.users.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.users.isEmpty) {
            return _buildEmptyState();
          }

          final users = provider.users;

          return RefreshIndicator(
            onRefresh: _loadUsers,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(indent: 80, height: 1),
              itemBuilder: (context, index) {
                final user = users[index];
                return _buildUserTile(user, provider);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadUsers,
        backgroundColor: const Color(0xFF00A884),
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  AppBar _buildDefaultAppBar(ThemeViewModel themeProvider) {
    return AppBar(
      title: const Text('MessageHub', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _isSearching = true),
        ),
        IconButton(
          icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
          onPressed: () => themeProvider.toggleTheme(),
        ),
        PopupMenuButton(
          onSelected: (value) {
            if (value == 'profile') _showProfileBottomSheet(context);
            if (value == 'switch_account') _showSwitchAccountDialog(context);
            if (value == 'clear') _showClearChatsDialog(context);
            if (value == 'logout') _showLogoutDialog(context);
            if (value == 'delete') _showDeleteAccountDialog(context);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'profile', child: Text('Profile')),
            const PopupMenuItem(value: 'switch_account', child: Text('Switch Account')),
            const PopupMenuItem(value: 'clear', child: Text('Clear All Chats')),
            const PopupMenuItem(value: 'logout', child: Text('Logout')),
            const PopupMenuItem(value: 'delete', child: Text('Delete Account', style: TextStyle(color: Colors.red))),
          ],
        ),
      ],
    );
  }

  AppBar _buildSearchAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          setState(() => _isSearching = false);
          _searchController.clear();
          context.read<ChatProvider>().setUserSearch('');
        },
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Search contacts...',
          border: InputBorder.none,
        ),
        onChanged: (val) => context.read<ChatProvider>().setUserSearch(val),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No contacts found', style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _loadUsers, child: const Text('Sync Contacts')),
        ],
      ),
    );
  }

  Widget _buildUserTile(ChatUser user, ChatProvider provider) {
    final unreadCount = provider.unreadCounts[user.id] ?? 0;
    final isOnline = provider.onlineStatus[user.id] ?? false;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: user.profilePic != null && user.profilePic!.isNotEmpty
                ? CachedNetworkImageProvider(ApiService.getImageUrl(user.profilePic!))
                : null,
            child: user.profilePic == null || user.profilePic!.isEmpty
                ? const Icon(Icons.person, size: 30)
                : null,
          ),
          if (isOnline)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(
        user.lastMessage ?? user.bio,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: unreadCount > 0 ? Colors.green : Colors.grey, fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (user.lastMessageTime != null)
            Text(
              DateFormatter.formatTimestamp(user.lastMessageTime!),
              style: TextStyle(color: unreadCount > 0 ? Colors.green : Colors.grey, fontSize: 11),
            ),
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(user: user)));
      },
    );
  }

  void _showProfileBottomSheet(BuildContext context) {
    final provider = context.read<ChatProvider>();
    final user = provider.currentUser;
    final bioController = TextEditingController(text: user?.bio);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildProfileImagePicker(provider),
              const SizedBox(height: 20),
              TextField(
                controller: bioController,
                decoration: const InputDecoration(labelText: 'About', prefixIcon: Icon(Icons.info_outline)),
                maxLength: 50,
              ),
              ElevatedButton(
                onPressed: () {
                  provider.updateBio(bioController.text);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white),
                child: const Text('Save Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImagePicker(ChatProvider p) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundImage: p.currentUser?.profilePic != null && p.currentUser!.profilePic!.isNotEmpty
              ? CachedNetworkImageProvider(ApiService.getImageUrl(p.currentUser!.profilePic!))
              : null,
          child: p.currentUser?.profilePic == null || p.currentUser!.profilePic!.isEmpty
              ? const Icon(Icons.person, size: 60)
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: CircleAvatar(
            backgroundColor: const Color(0xFF00A884),
            radius: 20,
            child: IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              onPressed: () => _showImageSourcePicker(p),
            ),
          ),
        ),
      ],
    );
  }

  void _showImageSourcePicker(ChatProvider p) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Gallery'), onTap: () { Navigator.pop(context); p.updateProfilePhoto(ImageSource.gallery); }),
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Camera'), onTap: () { Navigator.pop(context); p.updateProfilePhoto(ImageSource.camera); }),
          if (p.currentUser?.profilePic != null && p.currentUser!.profilePic!.isNotEmpty)
            ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Remove'), onTap: () { Navigator.pop(context); p.removeProfilePhoto(); }),
        ],
      ),
    );
  }

  void _showSwitchAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: context.read<ChatProvider>().getSavedAccounts(),
        builder: (context, snapshot) {
          final accounts = snapshot.data ?? [];
          final currentUser = context.read<ChatProvider>().currentUser;

          return AlertDialog(
            title: const Text('Switch Account'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...accounts.map((acc) {
                    final user = ChatUser.fromJson(acc['user']);
                    final isCurrent = user.id == currentUser?.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.profilePic != null && user.profilePic!.isNotEmpty
                            ? CachedNetworkImageProvider(ApiService.getImageUrl(user.profilePic!))
                            : null,
                        child: user.profilePic == null || user.profilePic!.isEmpty ? const Icon(Icons.person) : null,
                      ),
                      title: Text(user.name.trim().isNotEmpty ? user.name : user.phone),
                      trailing: isCurrent ? const Icon(Icons.check_circle, color: Colors.green) : null,
                      onTap: isCurrent ? null : () async {
                        Navigator.pop(context);
                        await context.read<ChatProvider>().switchAccount(acc);
                        _loadUsers();
                      },
                    );
                  }).toList(),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('Add Account'),
                    onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())); },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showClearChatsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Chats?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () async { Navigator.pop(context); await context.read<ChatProvider>().clearAllChats(); }, child: const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () async { Navigator.pop(context); await context.read<ChatProvider>().logout(); Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false); }, child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account?', style: TextStyle(color: Colors.red)),
        content: const Text('This will delete all your data permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async { 
              Navigator.pop(context); 
              final result = await context.read<ChatProvider>().deleteAccount(); 
              if (result == 1 && context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
              } else if (result == 2 && context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false); 
              }
            }, 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
