import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'admin_approvals.dart';
import 'add_withdrawal.dart';

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
  String _userId = '';
  double _totalEarned = 0;
  double _totalWithdrawn = 0;
  double _pendingAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      _userId = user.id;

      final profile = await _supabase.from('profiles').select().eq('id', _userId).single();
      final workLogs = await _supabase.from('work_logs').select().eq('worker_id', _userId);
      final withdrawals = await _supabase.from('withdrawals').select().eq('worker_id', _userId);

      double earned = 0, pending = 0, withdrawn = 0;
      for (var log in workLogs) {
        if (log['is_approved'] == true) earned += (log['total_sum'] ?? 0).toDouble();
        else pending += (log['total_sum'] ?? 0).toDouble();
      }
      for (var w in withdrawals) withdrawn += (w['amount'] ?? 0).toDouble();

      setState(() {
        _userName = profile['full_name'] ?? 'Xodim';
        _userRole = profile['role'] ?? 'worker';
        _totalEarned = earned;
        _totalWithdrawn = withdrawn;
        _pendingAmount = pending;
        _isLoading = false;
      });
    } catch (e) { setState(() => _isLoading = false); }
  }
  // --- DAVOMI PASTDA ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text("Hisobcheck: $_userName"),
        actions: [IconButton(onPressed: () async {
          await _supabase.auth.signOut();
          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        }, icon: const Icon(Icons.logout, color: Colors.red))],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildBalanceCard(),
              const SizedBox(height: 20),
              _buildMenuBtn("Ish Qo'shish", Icons.add_circle, Colors.blue, _showWorkDialog),
              
              if (_userRole == 'admin') ...[
                const SizedBox(height: 30),
                const Divider(),
                const Text("ADMIN PANEL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _buildMenuBtn("Tasdiqlash", Icons.fact_check, Colors.purple, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalsScreen()));
                    }),
                    const SizedBox(width: 10),
                    _buildMenuBtn("Pul Berish", Icons.payments, Colors.green, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWithdrawalScreen()));
                    }),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.blue.shade900, borderRadius: BorderRadius.circular(15)),
      child: Column(children: [
        const Text("Qoldiq", style: TextStyle(color: Colors.white70)),
        Text("${(_totalEarned - _totalWithdrawn).toStringAsFixed(0)} so'm", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        const Divider(color: Colors.white24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Ishlangan: $_totalEarned", style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
          Text("Olingan: $_totalWithdrawn", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _buildMenuBtn(String t, IconData i, Color c, VoidCallback onTap) {
    return Expanded(child: ElevatedButton.icon(onPressed: onTap, icon: Icon(i), label: Text(t), style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15))));
  }

  void _showWorkDialog() async {
      // --- [ 7. ISH QO'SHISH MODAL OYNASI ] ---
  void _showWorkDialog() async {
    // Bazadan ma'lumotlarni yuklab olamiz
    final orders = await _supabase.from('orders').select();
    final taskTypes = await _supabase.from('task_types').select();

    if (!mounted) return;

    // Tanlangan qiymatlarni saqlash uchun o'zgaruvchilar
    String? selectedOrderId;
    Map<String, dynamic>? selectedTask;
    final areaController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 25, 
            left: 25, 
            right: 25, 
            top: 25
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  "Bajarilgan ishni kiritish", 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                )
              ),
              const SizedBox(height: 25),
              
              // 1. ZAKAZ TANLASH
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Zakaz raqami", 
                  border: OutlineInputBorder()
                ),
                items: orders.map((o) => DropdownMenuItem(
                  value: o['id'].toString(), 
                  child: Text(o['order_number'] ?? "Noma'lum")
                )).toList(),
                onChanged: (v) => selectedOrderId = v,
              ),
              const SizedBox(height: 15),
              
              // 2. ISH TURI TANLASH
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(
                  labelText: "Ish turi", 
                  border: OutlineInputBorder()
                ),
                items: taskTypes.map((t) => DropdownMenuItem(
                  value: t, 
                  child: Text("${t['name']} (${t['default_rate']} so'm)")
                )).toList(),
                onChanged: (v) => setModalState(() => selectedTask = v),
              ),
              const SizedBox(height: 15),
              
              // 3. HAJM KIRITISH (m2)
              TextField(
                controller: areaController,
                decoration: const InputDecoration(
                  labelText: "Hajmi (m2)", 
                  border: OutlineInputBorder(), 
                  prefixIcon: Icon(Icons.straighten)
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setModalState(() {}), // Narxni real-vaqtda hisoblash uchun
              ),
              
              // 4. TAXMINIY HISOBNI KO'RSATISH
              if (selectedTask != null && areaController.text.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Hisoblangan summa:", style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        "${(double.tryParse(areaController.text) ?? 0) * (selectedTask!['default_rate'] ?? 0)} so'm",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 25),
              
              // 5. YUBORISH TUGMASI
              ElevatedButton(
                onPressed: () async {
                  // Validatsiya
                  if (selectedOrderId == null || selectedTask == null || areaController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Iltimos, barcha maydonlarni to'ldiring!"))
                    );
                    return;
                  }

                  try {
                    final area = double.parse(areaController.text);
                    final rate = selectedTask!['default_rate'];

                    await _supabase.from('work_logs').insert({
                      'worker_id': _userId,
                      'order_id': int.parse(selectedOrderId!),
                      'task_type': selectedTask!['name'],
                      'area_m2': area,
                      'rate': rate,
                      // Admin kiritgan ish avtomatik tasdiqlanadi
                      'is_approved': _userRole == 'admin', 
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      _loadAllData(); // Balansni yangilash
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Muvaffaqiyatli saqlandi!"))
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Xatolik: $e"))
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55), 
                  backgroundColor: Colors.blue.shade900, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: const Text("BAZAGA YUBORISH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  }
}
