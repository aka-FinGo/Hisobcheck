import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _userName = '';
  String _userRole = 'worker';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final profile = await _supabase.from('profiles').select().eq('id', user.id).single();
      setState(() {
        _userName = profile['full_name'] ?? 'Xodim';
        _userRole = profile['role'] ?? 'worker';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text("Salom, $_userName"),
        actions: [
          IconButton(onPressed: () => _supabase.auth.signOut(), icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildBalanceSummary(), // Balansni ko'rsatuvchi widget
            const SizedBox(height: 20),
            Row(
              children: [
                _buildMenuBtn("Ish Qo'shish", Icons.add_box, Colors.blue, _showWorkDialog),
                const SizedBox(width: 10),
                _buildMenuBtn("Tarix", Icons.history, Colors.orange, () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- UI KOMPONENTLARI ---

  Widget _buildBalanceSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade900,
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Column(
        children: [
          Text("Joriy Qoldiq", style: TextStyle(color: Colors.white70)),
          Text("0 so'm", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMenuBtn(String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
      ),
    );
  }

  // --- ASOSIY MANTIQ: ISH QO'SHISH OYNASI ---

  void _showWorkDialog() async {
    // 1. Bazadan Zakazlar va Tariflarni yuklab olamiz
    final orders = await _supabase.from('orders').select();
    final taskTypes = await _supabase.from('task_types').select();

    if (!mounted) return;

    String? selectedOrderId;
    Map<String, dynamic>? selectedTask;
    final areaController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Yangi Ish Kiritish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              
              // ZAKAZ TANLASH
              DropdownButtonFormField(
                decoration: const InputDecoration(labelText: "Zakazni tanlang"),
                items: orders.map((o) => DropdownMenuItem(value: o['id'].toString(), child: Text(o['order_number']))).toList(),
                onChanged: (val) => selectedOrderId = val as String?,
              ),
              const SizedBox(height: 10),

              // ISH TURINI TANLASH
              DropdownButtonFormField(
                decoration: const InputDecoration(labelText: "Ish turi (Tarif)"),
                items: taskTypes.map((t) => DropdownMenuItem(value: t, child: Text("${t['name']} (${t['default_rate']} so'm)"))).toList(),
                onChanged: (val) => setModalState(() => selectedTask = val as Map<String, dynamic>?),
              ),
              const SizedBox(height: 10),

              // KVADRAT METR KIRITISH
              TextField(
                controller: areaController,
                decoration: const InputDecoration(labelText: "Kvadrat metr (m2)", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),

              // HISOBLANGAN SUMMANI KO'RSATISH
              if (selectedTask != null && areaController.text.isNotEmpty)
                Text(
                  "Hisob: ${(double.tryParse(areaController.text) ?? 0) * selectedTask!['default_rate']} so'm",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (selectedOrderId == null || selectedTask == null || areaController.text.isEmpty) return;

                  await _supabase.from('work_logs').insert({
                    'worker_id': _supabase.auth.currentUser!.id,
                    'order_id': int.parse(selectedOrderId!),
                    'task_type': selectedTask!['name'],
                    'area_m2': double.parse(areaController.text),
                    'rate': selectedTask!['default_rate'],
                    'is_approved': false, // Admin tasdiqlashi shart
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ish saqlandi! Admin tasdiqlashini kuting.")));
                  }
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text("BAZAGA YUBORISH"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
