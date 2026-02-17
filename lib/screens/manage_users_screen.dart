import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase.from('profiles').select().order('full_name');
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateRole(String userId, String newRole) async {
    await _supabase.from('profiles').update({'role': newRole}).eq('id', userId);
    _loadUsers();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lavozim o'zgardi: $newRole")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Xodimlar va Lavozimlar")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (ctx, i) {
                final user = _users[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(child: Text((user['full_name']?[0] ?? "U").toUpperCase())),
                    title: Text(user['full_name'] ?? "Noma'lum"),
                    subtitle: Text("Tel: ${user['phone'] ?? '-'}"),
                    trailing: DropdownButton<String>(
                      value: ['admin', 'worker', 'designer', 'driver', 'installer'].contains(user['role']) 
                          ? user['role'] 
                          : 'worker',
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text("Admin")),
                        DropdownMenuItem(value: 'worker', child: Text("Ishchi (Umumiy)")),
                        DropdownMenuItem(value: 'designer', child: Text("Loyihachi")),
                        DropdownMenuItem(value: 'driver', child: Text("Haydovchi")),
                        DropdownMenuItem(value: 'installer', child: Text("O'rnatuvchi")),
                      ],
                      onChanged: (val) {
                        if (val != null) _updateRole(user['id'], val);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}