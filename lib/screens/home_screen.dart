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
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text("Hisobcheck: $_userName"),
        actions: [
          IconButton(
            onPressed: () async {
              await _supabase.auth.signOut();
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            }, 
            icon: const Icon(Icons.logout, color: Colors.red)
          )
        ],
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
              
              // 1. ISH QO'SHISH TUGMASI (Row ichiga olindi)
              Row(
                children: [
                  _buildMenuBtn("Ish Qo'shish", Icons.add_circle, Colors.blue, _showWorkDialog),
                ],
              ),
              
              // 2. ADMIN PANEL
              if (_userRole == 'admin') ...[
                const SizedBox(height: 30),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text("ADMIN PANEL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                ),
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

  // TUGMA VIDJETI: Expanded faqat Row ichida ishlaydi
  Widget _buildMenuBtn(String t, IconData i, Color c, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onTap, 
        icon: Icon(i), 
        label: Text(t), 
        style: ElevatedButton.styleFrom(
          backgroundColor: c, 
          foregroundColor: Colors.white, 
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
        )
      )
    );
  }

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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 25, left: 25, right: 25, top: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: Text("Bajarilgan ishni kiritish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              const SizedBox(height: 25),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Zakaz raqami", border: OutlineInputBorder()),
                items: orders.map((o) => DropdownMenuItem(
                  value: o['id'].toString(), 
                  child: Text("${o['order_number']} (${o['total_area_m2'] ?? 0} m2)")
                )).toList(),
                onChanged: (v) {
                  selectedOrderId = v;
                  final selectedOrder = orders.firstWhere((o) => o['id'].toString() == v);
                  setModalState(() {
                    areaController.text = selectedOrder['total_area_m2']?.toString() ?? "0";
                  });
                },
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(labelText: "Ish turi", border: OutlineInputBorder()),
                items: taskTypes.map((t) => DropdownMenuItem(
                  value: t, 
                  child: Text("${t['name']} (${t['default_rate']} so'm)")
                )).toList(),
                onChanged: (v) => setModalState(() => selectedTask = v),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: areaController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Hajmi (m2) - Bek tomonidan belgilangan", 
                  filled: true, fillColor: Colors.grey.shade100,
                  border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.lock_outline)
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () async {
                  if (selectedOrderId == null || selectedTask == null || areaController.text.isEmpty) return;
                  try {
                    await _supabase.from('work_logs').insert({
                      'worker_id': _userId,
                      'order_id': int.parse(selectedOrderId!),
                      'task_type': selectedTask!['name'],
                      'area_m2': double.parse(areaController.text),
                      'rate': selectedTask!['default_rate'],
                      'is_approved': _userRole == 'admin', 
                    });
                    if (mounted) { Navigator.pop(context); _loadAllData(); }
                  } catch (e) { print(e); }
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                child: const Text("BAZAGA YUBORISH"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
