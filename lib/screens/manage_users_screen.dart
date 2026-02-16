import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_screen.dart'; // Profil sahifasini import qilamiz

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _users = [];
  bool _isLoading = true;

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
      debugPrint("Xodimlar yuklanmadi: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Xodimlar", style: TextStyle(fontWeight: FontWeight.bold)),
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
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final bool isSuperAdmin = user['is_super_admin'] == true;
                final bool isMe = user['id'] == _supabase.auth.currentUser?.id;

                return GestureDetector(
                  onTap: () {
                    // Xodim ustiga bosilganda uning profiliga o'tamiz
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(user: user),
                      ),
                    ).then((_) => _loadUsers()); // Profil sahifasidan qaytganda ma'lumotni yangilash
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar (Ijtimoiy tarmoq uslubida)
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: isSuperAdmin ? Colors.amber.shade100 : Colors.blue.shade50,
                              child: Text(
                                (user['full_name'] ?? "?")[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isSuperAdmin ? Colors.amber.shade900 : Colors.blue.shade900,
                                ),
                              ),
                            ),
                            if (isSuperAdmin)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                                  child: const Icon(Icons.workspace_premium, size: 14, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 15),
                        // Ma'lumotlar
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${user['full_name'] ?? 'Noma\'lum'} ${isMe ? '(Siz)' : ''}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user['role']?.toUpperCase() ?? 'WORKER',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // O'tish belgisi
                        Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
