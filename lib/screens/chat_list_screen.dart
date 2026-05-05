import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_provider.dart';
import '../services/theme_provider.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isLoaded) {
      _isLoaded = true;
      _loadUsers();
    }
  }

  Future<void> _loadUsers() async {
    await context.read<ChatProvider>().fetchContactsAndMatch();
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<ChatProvider>().logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/auth', (route) => false);
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MessageHub'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          PopupMenuButton(
            onSelected: (value) {
              if (value == 'logout') _showLogoutDialog(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'logout',
                child: Text('Logout', style: TextStyle(color: Colors.red)),
              )
            ],
          ),
        ],
      ),

      // ===========================
      // 📱 BODY
      // ===========================
      body: Consumer<ChatProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.users.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 50),
                  const SizedBox(height: 10),
                  Text(provider.error!),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _loadUsers,
                    child: const Text('Retry'),
                  )
                ],
              ),
            );
          }

          if (provider.users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No contacts using MessageHub',
                    style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _loadUsers,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Sync Contacts'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  )
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadUsers,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: provider.users.length,
              separatorBuilder: (_, __) => const Divider(indent: 80, height: 1),
              itemBuilder: (context, index) {
                final user = provider.users[index];

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blue.shade50,
                    backgroundImage: user.profilePic != null &&
                        user.profilePic!.isNotEmpty
                        ? NetworkImage(user.profilePic!)
                        : null,
                    child: user.profilePic == null ||
                        user.profilePic!.isEmpty
                        ? Icon(Icons.person, color: Colors.blue.shade300, size: 30)
                        : null,
                  ),

                  title: Text(
                    user.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.phone, style: TextStyle(color: Colors.grey.shade600)),
                      const Text(
                        'Tap to chat',
                        style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),

                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(user: user),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),

      // ===========================
      // ➕ FAB (Optional)
      // ===========================
      floatingActionButton: FloatingActionButton(
        onPressed: _loadUsers,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}