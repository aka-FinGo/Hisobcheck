import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_screen.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _users = [];
  List<dynamic> _roles = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final rolesRes = await _supabase.from('app_roles').select().order('name');
      final usersRes = await _supabase.from('profiles').select('*, app_roles(name, role_type)').order('full_name');
      setState(() {
        _roles = rolesRes;
        _users = usersRes;
      });
    } catch (e) {
      debugPrint("Xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // TEZKOR LAVOZIM BERISH (QUICK EDIT)
  void _showQuickRoleEdit(Map<String, dynamic> user) {
    int? selectedRoleId = user['position_id'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("${user['full_name']} uchun lavozim"),
        content: DropdownButtonFormField<int>(
          value: selectedRoleId,
          items: _roles.map((r) => DropdownMenuItem<int>(value: r['id'], child: Text(r['name']))).toList(),
          onChanged: (v) => selectedRoleId = v,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Lavozimni tanlang"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor qilish")),
          ElevatedButton(
            onPressed: () async {
              await _supabase.from('profiles').update({'position_id': selectedRoleId}).eq('id', user['id']);
              Navigator.pop(ctx);
              _fetchData(); // Ro'yxatni yangilash
            },
            child: const Text("Saqlash"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Xodimlar boshqaruvi"), elevation: 0),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final bool isSuper = user['is_super_admin'] == true;

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: user['id']))),
                      child: CircleAvatar(
                        backgroundColor: isSuper ? Colors.amber.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
                        child: Text(user['full_name']?[0] ?? 'U', style: TextStyle(color: isSuper ? Colors.amber : Colors.blue)),
                      ),
                    ),
                    title: Text(user['full_name'] ?? 'Ismsiz', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(user['app_roles']?['name'] ?? 'Lavozim belgilanmagan'),
                    trailing: isSuper ? const Icon(Icons.shield, color: Colors.amber, size: 20) : IconButton(
                      icon: const Icon(Icons.settings_suggest_outlined, color: Colors.blue),
                      onPressed: () => _showQuickRoleEdit(user),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
