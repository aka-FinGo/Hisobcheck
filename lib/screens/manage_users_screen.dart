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
    // is_super_admin ustunini ham yuklaymiz
    final data = await _supabase.from('profiles').select().order('created_at');
    setState(() {
      _users = data;
      _isLoading = false;
    });
  }

  Future<void> _updateRole(String userId, String newRole) async {
    try {
      await _supabase.from('profiles').update({'role': newRole}).eq('id', userId);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rol $newRole ga o'zgardi!")));
      _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xatolik: $e")));
    }
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
              
              // SUPER ADMINNI TEKSHIRISH
              final bool isSuperAdmin = user['is_super_admin'] == true;
              final bool isMe = user['id'] == _supabase.auth.currentUser?.id;

              return Card(
                color: isSuperAdmin ? Colors.amber.shade50 : null,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSuperAdmin ? Colors.amber : Colors.blue,
                    // TUZATILGAN JOY: Icons.crown o'rniga Icons.workspace_premium ishlatildi
                    child: Icon(isSuperAdmin ? Icons.workspace_premium : Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    "${user['full_name'] ?? 'Noma\'lum'} ${isMe ? '(Siz)' : ''}", 
                    style: TextStyle(fontWeight: FontWeight.bold, color: isSuperAdmin ? Colors.amber.shade900 : Colors.black)
                  ),
                  subtitle: Text(isSuperAdmin ? "BOSHLIQ (Daxlsiz)" : "Rol: ${user['role']}"),
                  
                  trailing: isSuperAdmin
                      ? const Chip(
                          label: Text("Daxlsiz"), 
                          avatar: Icon(Icons.lock, size: 16),
                          backgroundColor: Colors.transparent,
                        )
                      : DropdownButton<String>(
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
