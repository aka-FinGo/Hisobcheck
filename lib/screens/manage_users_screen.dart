import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _users = [];
  bool _isLoading = true;

  // Tizimdagi mavjud rollar
  final List<String> _roles = ['worker', 'admin', 'bek', 'painter', 'assembler'];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final data = await _supabase.from('profiles').select().order('created_at');
    setState(() {
      _users = data;
      _isLoading = false;
    });
  }

  Future<void> _updateRole(String userId, String newRole) async {
    await _supabase.from('profiles').update({'role': newRole}).eq('id', userId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rol $newRole ga o'zgardi!")));
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Xodimlarni Boshqarish")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(user['full_name']?[0] ?? 'X')),
                  title: Text(user['full_name'] ?? 'Noma\'lum'),
                  subtitle: Text("Hozirgi rol: ${user['role']}"),
                  trailing: DropdownButton<String>(
                    value: _roles.contains(user['role']) ? user['role'] : 'worker',
                    items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
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
