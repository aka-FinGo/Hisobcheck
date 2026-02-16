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
  late TextEditingController _phoneController;
  late String _selectedRole;
  bool _isLoading = true;

  // Xodim statistikasi uchun o'zgaruvchilar
  double _earned = 0;
  double _withdrawn = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['full_name']);
    _phoneController = TextEditingController(text: widget.user['phone'] ?? '');
    _selectedRole = widget.user['role'] ?? 'worker';
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    try {
      // Ishchining ishlab topgan puli
      final logs = await _supabase.from('work_logs').select('total_sum').eq('worker_id', widget.user['id']).eq('is_approved', true);
      // Ishchi olgan pullar
      final draws = await _supabase.from('withdrawals').select('amount').eq('worker_id', widget.user['id']);

      double e = 0; double w = 0;
      for (var l in logs) e += (l['total_sum'] ?? 0).toDouble();
      for (var d in draws) w += (d['amount'] ?? 0).toDouble();

      setState(() {
        _earned = e; _withdrawn = w;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserData() async {
    try {
      await _supabase.from('profiles').update({
        'full_name': _nameController.text,
        'phone': _phoneController.text,
        'role': _selectedRole,
      }).eq('id', widget.user['id']);
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saqlandi!"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Xodim Profili")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 1. STATISTIKA BLOKI
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.blue.shade900, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem("Ishladi", _earned, Colors.greenAccent),
                      _statItem("Oldi", _withdrawn, Colors.orangeAccent),
                      _statItem("Qoldi", _earned - _withdrawn, Colors.white),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // 2. MA'LUMOTLARNI TAHRIRLASH
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: "F.I.SH", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "Telefon", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: "Roli", border: OutlineInputBorder()),
                  items: ['worker', 'admin', 'bek', 'painter'].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                  onChanged: (v) => setState(() => _selectedRole = v!),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: _updateUserData,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue.shade900),
                  child: const Text("SAQLASH", style: TextStyle(color: Colors.white)),
                ),
                
                const Divider(height: 50),

                // 3. XAVFSIZLIK (Login/Parol)
                const Text("Xavfsizlik", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 15),
                ListTile(
                  leading: const Icon(Icons.lock_reset, color: Colors.red),
                  title: const Text("Parolni yangilash"),
                  subtitle: const Text("Xodim uchun yangi parol o'rnatish"),
                  onTap: _showPasswordResetDialog,
                ),
              ],
            ),
          ),
    );
  }

  Widget _statItem(String label, double val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text("${val.toInt()}", style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showPasswordResetDialog() {
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yangi parol"),
        content: TextField(controller: passController, decoration: const InputDecoration(hintText: "Kamida 6 ta belgi")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("BEKOR")),
          ElevatedButton(
            onPressed: () async {
              // Supabase Auth orqali parolni Admin tomonidan o'zgartirish mantiqi
              // Eslatma: Bu funksiya uchun Supabase Service Role kerak yoki
              // Edge Function yozish kerak. Oddiy foydalanuvchi boshqaning parolini o'zgartirolmaydi.
              Navigator.pop(context);
            }, 
            child: const Text("O'ZGARTIRISH")
          ),
        ],
      ),
    );
  }
}
