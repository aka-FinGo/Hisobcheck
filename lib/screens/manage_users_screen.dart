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
  String? _currentUserId; // Hozir tizimda o'tirgan Adminning ID si

  List<String> _availableRoles = ['admin', 'worker', 'installer', 'manager'];

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id; // Adminni tanib olamiz
    _fetchUsersAndRoles();
  }

  Future<void> _fetchUsersAndRoles() async {
    setState(() => _isLoading = true);
    try {
      final usersResponse = await _supabase
          .from('profiles')
          .select('id, full_name, role, phone, created_at')
          .order('created_at', ascending: true);
          
      final rolesResponse = await _supabase.from('task_types').select('target_role');
      
      final Set<String> dynamicRoles = {'admin', 'worker', 'installer', 'manager'};
      for (var item in rolesResponse) {
        if (item['target_role'] != null && item['target_role'].toString().trim().isNotEmpty) {
          dynamicRoles.add(item['target_role'].toString().trim().toLowerCase());
        }
      }

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(usersResponse);
          _availableRoles = dynamicRoles.toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      await _supabase.from('profiles').update({'role': newRole}).eq('id', userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rol muvaffaqiyatli o'zgartirildi!"), backgroundColor: Colors.green),
        );
        _fetchUsersAndRoles(); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _showRoleDialog(Map<String, dynamic> user) {
    String selectedRole = user['role'] ?? 'worker';
    
    if (!_availableRoles.contains(selectedRole)) {
      _availableRoles.add(selectedRole);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${user['full_name'] ?? 'Foydalanuvchi'} rolini o'zgartirish"),
        content: DropdownButtonFormField<String>(
          value: selectedRole,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Yangi rol"),
          items: _availableRoles.map((role) {
            return DropdownMenuItem(value: role, child: Text(role.toUpperCase()));
          }).toList(),
          onChanged: (val) {
            if (val != null) selectedRole = val;
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E5BFF), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _updateUserRole(user['id'], selectedRole);
            },
            child: const Text("SAQLASH"),
          )
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return Colors.redAccent;
      case 'manager': return Colors.orange;
      case 'installer': return Colors.purple;
      case 'worker': return Colors.green;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Xodimlarni boshqarish", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF2E5BFF)), onPressed: _fetchUsersAndRoles),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final role = user['role'] ?? 'Noma\'lum';
                final name = user['full_name'] ?? 'Ism kiritilmagan';
                
                // SHU YERDA TEKSHIRAMIZ: Bu ro'yxatdagi odam Hozirgi Adminning o'zimi?
                final bool isMe = user['id'] == _currentUserId;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: _getRoleColor(role).withOpacity(0.2),
                      child: Icon(Icons.person, color: _getRoleColor(role)),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Rol: ${role.toUpperCase()}", style: TextStyle(color: _getRoleColor(role), fontWeight: FontWeight.w600)),
                    trailing: isMe 
                        // Agar o'zi bo'lsa, tahrirlash tugmasi o'rniga "Qalqon" (Himoya) belgisi chiqadi
                        ? const Tooltip(
                            message: "Asosiy Adminni o'zgartirib bo'lmaydi",
                            child: Icon(Icons.security, color: Colors.redAccent, size: 28),
                          )
                        // Agar boshqa ishchi bo'lsa, ruchka chiqadi
                        : IconButton(
                            icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF2E5BFF), size: 30),
                            onPressed: () => _showRoleDialog(user),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
