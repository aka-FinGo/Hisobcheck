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

  // Tizimdagi barcha mavjud rollar
  final List<String> _roles = ['worker', 'admin', 'bek', 'painter', 'assembler'];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('profiles').select().order('full_name');
      setState(() {
        _users = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Yuklashda xato: $e");
      setState(() => _isLoading = false);
    }
  }

  // Rolni yangilash funksiyasi
  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      await _supabase.from('profiles').update({'role': newRole}).eq('id', userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Rol muvaffaqiyatli o'zgardi: $newRole"), backgroundColor: Colors.green),
      );
      _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xatolik: $e")));
    }
  }

  // Xodimni o'chirish (Tasdiqlash bilan)
  Future<void> _deleteUser(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xodimni o'chirish"),
        content: Text("$name ni tizimdan o'chirmoqchimisiz? Bu amalni ortga qaytarib bo'lmaydi!"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("BEKOR QILISH")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("O'CHIRISH", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('profiles').delete().eq('id', userId);
        _loadUsers();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Xodim o'chirildi")));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xatolik: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Xodimlarni Boshqarish", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadUsers, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final bool isSuperAdmin = user['is_super_admin'] == true;
                final bool isMe = user['id'] == _supabase.auth.currentUser?.id;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                    border: isSuperAdmin ? Border.all(color: Colors.amber, width: 2) : null,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: isSuperAdmin ? Colors.amber : Colors.blue.shade900,
                      child: Text(
                        (user['full_name'] ?? "?")[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${user['full_name'] ?? 'Noma\'lum'} ${isMe ? '(Siz)' : ''}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        if (isSuperAdmin)
                          const Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSuperAdmin ? Colors.amber.shade100 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isSuperAdmin ? "BOSHLIQ" : "ROL: ${user['role']?.toUpperCase()}",
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.bold, 
                              color: isSuperAdmin ? Colors.amber.shade900 : Colors.blue.shade900
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: isSuperAdmin
                        ? const Icon(Icons.lock_outline, color: Colors.grey)
                        : IconButton(
                            icon: const Icon(Icons.settings, color: Colors.blueGrey),
                            onPressed: () => _showUserOptions(user),
                          ),
                  ),
                );
              },
            ),
    );
  }

  // Xodim sozlamalari oynasi (Tahrirlash va O'chirish)
  void _showUserOptions(Map<String, dynamic> user) {
    String currentRole = user['role'] ?? 'worker';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${user['full_name']} - Sozlamalar",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              const Text("Xodim rolini tanlang:", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              
              // Rollar ro'yxati (Grid ko'rinishida)
              Wrap(
                spacing: 8,
                children: _roles.map((role) {
                  bool isSelected = currentRole == role;
                  return ChoiceChip(
                    label: Text(role.toUpperCase()),
                    selected: isSelected,
                    selectedColor: Colors.blue.shade900,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                    onSelected: (selected) {
                      if (selected) {
                        setModalState(() => currentRole = role);
                      }
                    },
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 30),
              
              // Saqlash tugmasi
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateUserRole(user['id'], currentRole);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blue.shade900,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("O'ZGARISHLARNI SAQLASH", style: TextStyle(color: Colors.white)),
              ),
              
              const SizedBox(height: 10),
              
              // O'chirish tugmasi
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteUser(user['id'], user['full_name']);
                },
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text("XODIMNI O'CHIRISH", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
