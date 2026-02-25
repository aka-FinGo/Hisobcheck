import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_screen.dart'; // Profil sahifasiga o'tish uchun

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('profiles')
          .select('*, app_roles(name, role_type)')
          .order('full_name');
      setState(() => _users = response);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Xodimlar boshqaruvi")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final bool isSuper = user['is_super_admin'] == true;
                final String roleName = user['app_roles'] != null ? user['app_roles']['name'] : 'Lavozimsiz';

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSuper ? Colors.amber.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
                      child: Text(user['full_name']?[0] ?? 'U', style: TextStyle(color: isSuper ? Colors.amber : Colors.blue)),
                    ),
                    title: Text(user['full_name'] ?? 'Ismsiz'),
                    subtitle: Text(roleName),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // HODIM PROFILIGA O'TISH (Admin ko'rinishida)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(userId: user['id']),
                        ),
                      ).then((_) => _fetchUsers()); // Qaytganda ro'yxatni yangilash
                    },
                  ),
                );
              },
            ),
    );
  }
}
