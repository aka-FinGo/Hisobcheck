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
  
  // User ma'lumotlari
  String _userName = '';
  String _userRole = 'worker';
  String _userId = '';

  // Hisob-kitob ma'lumotlari
  double _totalEarned = 0;   // Jami ishlagan (tasdiqlangan)
  double _totalWithdrawn = 0; // Jami olgan (avanslar)
  double _pendingAmount = 0;  // Tasdiq kutilayotgan ishlar

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // 1. Ma'lumotlarni bazadan yangilash
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      _userId = user.id;

      // Profilni olish
      final profile = await _supabase.from('profiles').select().eq('id', _userId).single();
      
      // Balansni hisoblash (Work logs va Withdrawals)
      final workLogs = await _supabase.from('work_logs').select().eq('worker_id', _userId);
      final withdrawals = await _supabase.from('withdrawals').select().eq('worker_id', _userId);

      double earned = 0;
      double pending = 0;
      for (var log in workLogs) {
        if (log['is_approved'] == true) {
          earned += (log['total_sum'] ?? 0).toDouble();
        } else {
          pending += (log['total_sum'] ?? 0).toDouble();
        }
      }

      double withdrawn = 0;
      for (var w in withdrawals) {
        withdrawn += (w['amount'] ?? 0).toDouble();
      }

      setState(() {
        _userName = profile['full_name'] ?? 'Xodim';
        _userRole = profile['role'] ?? 'worker';
        _totalEarned = earned;
        _totalWithdrawn = withdrawn;
        _pendingAmount = pending;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Xato yuz berdi: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Aristokrat Mebel", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(onPressed: () => _supabase.auth.signOut(), icon: const Icon(Icons.logout, color: Colors.red)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. BALANS KARTASI
              _buildBalanceCard(),
              const SizedBox(height: 25),

              const Text("Asosiy Amallar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              // 2. ISHCHI TUGMALARI
              Row(
                children: [
                  _buildActionBtn("Ish Qo'shish", Icons.add_task, Colors.blue.shade800, _showWorkDialog),
                  const SizedBox(width: 12),
                  _buildActionBtn("Hamyon", Icons.wallet, Colors.green.shade700, () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tez kunda...")));
                  }),
                ],
              ),

              // 3. ADMIN BO'LIMI (Faqat admin uchun)
              if (_userRole == 'admin') ...[
                const SizedBox(height: 30),
                const Text("Admin Boshqaruvi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _buildActionBtn("Yangi Zakaz", Icons.post_add, Colors.red.shade700, () {}),
                    const SizedBox(width: 12),
                    _buildActionBtn("Tasdiqlash", Icons.rule, Colors.purple.shade700, () {}),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- UI QISMLARI ---

  Widget _buildBalanceCard() {
    double balance = _totalEarned - _totalWithdrawn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade700]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          const Text("Sizning Qoldig'ingiz", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text("${balance.toStringAsFixed(0)} so'm", 
               style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _balanceMiniStat("Ishlangan", _totalEarned, Colors.greenAccent),
              _balanceMiniStat("Olingan", _totalWithdrawn, Colors.orangeAccent),
            ],
          ),
          if (_pendingAmount > 0) ...[
            const Divider(color: Colors.white24, height: 25),
            Text("Tasdiq kutilmoqda: ${_pendingAmount.toStringAsFixed(0)} so'm", 
                 style: const TextStyle(color: Colors.white60, fontStyle: FontStyle.italic)),
          ]
        ],
      ),
    );
  }

  Widget _balanceMiniStat(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text("${amount.toStringAsFixed(0)}", style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionBtn(String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 8),
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- ISH QO'SHISH MODAL OYNASI ---

  void _showWorkDialog() async {
    final orders = await _supabase.from('orders').select();
    final taskTypes = await _supabase.from('task_types').select();

    if (!mounted) return;

    String? selectedOrderId;
    Map<String, dynamic>? selectedTask;
    final areaController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 25, right: 25, top: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text("Yangi Ish Qo'shish", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 25),
              
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Zakaz raqami", border: OutlineInputBorder()),
                items: orders.map((o) => DropdownMenuItem(value: o['id'].toString(), child: Text(o['order_number']))).toList(),
                onChanged: (v) => selectedOrderId = v,
              ),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(labelText: "Ish turi", border: OutlineInputBorder()),
                items: taskTypes.map((t) => DropdownMenuItem(value: t, child: Text("${t['name']} (${t['default_rate']} so'm)"))).toList(),
                onChanged: (v) => setModalState(() => selectedTask = v),
              ),
              const SizedBox(height: 15),
              
              TextField(
                controller: areaController,
                decoration: const InputDecoration(labelText: "Kvadrat metr (m2)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.square_foot)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setModalState(() {}),
              ),
              
              if (selectedTask != null && areaController.text.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text("Taxminiy hisob: ${(double.tryParse(areaController.text) ?? 0) * selectedTask!['default_rate']} so'm",
                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
              ],

              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () async {
                  if (selectedOrderId == null || selectedTask == null || areaController.text.isEmpty) return;
                  
                  final area = double.parse(areaController.text);
                  final rate = selectedTask!['default_rate'];

                  await _supabase.from('work_logs').insert({
                    'worker_id': _userId,
                    'order_id': int.parse(selectedOrderId!),
                    'task_type': selectedTask!['name'],
                    'area_m2': area,
                    'rate': rate,
                    'is_approved': false,
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    _loadAllData(); // Balansni yangilash
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ish yuborildi. Admin tasdiqlashini kuting.")));
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.blue.shade900,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("YUBORISH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
