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
  String _selectedRole = '';
  List<Map<String, dynamic>> _taskTypes = [];
  Map<String, TextEditingController> _rateControllers = {};

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user['role'] ?? 'worker';
    _loadTaskTypes();
  }

  Future<void> _loadTaskTypes() async {
    final tasks = await _supabase.from('task_types').select();
    setState(() {
      _taskTypes = List<Map<String, dynamic>>.from(tasks);
      for (var task in _taskTypes) {
        _rateControllers[task['name']] = TextEditingController(
          text: task['default_rate'].toString()
        );
      }
    });
  }

  Future<void> _saveChanges() async {
    try {
      // 1. Rolni yangilash
      await _supabase.from('profiles').update({'role': _selectedRole}).eq('id', widget.user['id']);
      
      // 2. Bu yerda xohlasangiz har bir ish turi uchun maxsus tariflarni saqlash mantiqini qo'shish mumkin
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("O'zgarishlar saqlandi!")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.user['full_name'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Xodim roli:", style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              isExpanded: true,
              value: _selectedRole,
              items: const [
                DropdownMenuItem(value: 'worker', child: Text("Ishchi (Usta)")),
                DropdownMenuItem(value: 'admin', child: Text("Admin")),
                DropdownMenuItem(value: 'owner', child: Text("Boshliq")),
              ],
              onChanged: (v) => setState(() => _selectedRole = v!),
            ),
            const SizedBox(height: 30),
            const Text("Ish turlari bo'yicha tariflar:", style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            ..._taskTypes.map((task) => ListTile(
              title: Text(task['name']),
              trailing: SizedBox(
                width: 100,
                child: TextField(
                  controller: _rateControllers[task['name']],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(suffixText: "so'm"),
                ),
              ),
            )),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveChanges,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue.shade900,
                foregroundColor: Colors.white
              ),
              child: const Text("SAQLASH"),
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () {
                // Xodimni o'chirish mantiqi
              },
              child: const Text("Xodimni o'chirish", style: TextStyle(color: Colors.red)),
            )
          ],
        ),
      ),
    );
  }
}
