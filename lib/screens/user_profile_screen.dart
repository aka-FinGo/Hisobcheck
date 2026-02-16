import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  late TextEditingController _nameController;
  late String _selectedRole;
  bool _isSaving = false;

  final List<String> _roles = ['worker', 'admin', 'bek', 'painter', 'assembler'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['full_name']);
    _selectedRole = widget.user['role'] ?? 'worker';
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _supabase.from('profiles').update({
        'full_name': _nameController.text,
        'role': _selectedRole,
      }).eq('id', widget.user['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ma'lumotlar saqlandi!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xatolik: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Xodim Profili")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Ism Familiya",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _roles.contains(_selectedRole) ? _selectedRole : 'worker',
              decoration: const InputDecoration(
                labelText: "Roli",
                border: OutlineInputBorder(),
              ),
              items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
              onChanged: (val) => setState(() => _selectedRole = val!),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isSaving ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                backgroundColor: Colors.blue.shade900,
              ),
              child: _isSaving 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("O'ZGARISHLARNI SAQLASH", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
