import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'admin_approvals.dart';
import 'add_withdrawal.dart';
import 'manage_users_screen.dart';
import 'clients_screen.dart';
import 'stats_screen.dart';
import 'user_profile_screen.dart';
import '../widgets/balance_card.dart';
import '../widgets/reload_button.dart'; // ReloadButton import qilindi

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _userRole = 'worker';
  String _userId = '';
  double _totalEarned = 0;
  double _totalWithdrawn = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      _userId = user.id;

      final profile = await _supabase.from('profiles').select().eq('id', _userId).single();
      _userRole = profile['role'] ?? 'worker';

      final workLogs = await _supabase.from('work_logs')
          .select('total_sum')
          .eq('worker_id', _userId)
          .eq('is_approved', true);

      final withdrawals = await _supabase.from('withdrawals')
          .select('amount')
          .eq('worker_id', _userId);

      double earned = 0, withdrawn = 0;
      for (var log in workLogs) earned += (log['total_sum'] ?? 0).toDouble();
      for (var w in withdrawals) withdrawn += (w['amount'] ?? 0).toDouble();

      if (mounted) {
        setState(() {
          _totalEarned = earned;
          _totalWithdrawn = withdrawn;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade900,
        title: const Text("Aristokrat Mebel", style: TextStyle(color: Colors.white)),
        actions: [
          // 1. Yangilash tugmasi (ReloadButton)
          ReloadButton(
            onRefresh: _loadAllData,
            color: Colors.white,
          ),
          
          // 2. Chiqish tugmasi (Logout)
          IconButton(
            onPressed: () async {
              await _supabase.auth.signOut();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            BalanceCard(
              earned: _totalEarned, 
              withdrawn: _totalWithdrawn,
              role: _userRole,
              onStatsTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
              },
            ),
            const SizedBox(height: 20),
            _buildMenuBtn("Ish Qo'shish", Icons.add_circle, Colors.blue, _showWorkDialog),
            
            if (_userRole == 'admin' || _userRole == 'owner') ...[
              const SizedBox(height: 10),
              _buildMenuBtn("Mijozlar & Zakazlar", Icons.people_alt, Colors.indigo, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen()));
              }),
              const SizedBox(height: 30),
              const Divider(),
              const Text("ADMIN PANEL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _buildMenuBtnSmall("Tasdiqlash", Icons.fact_check, Colors.purple, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalsScreen()));
                  })),
                  const SizedBox(width: 10),
                  Expanded(child: _buildMenuBtnSmall("Pul Berish", Icons.payments, Colors.green, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWithdrawalScreen()));
                  })),
                ],
              ),
              const SizedBox(height: 10),
              _buildMenuBtn("Xodimlar & Rollar", Icons.manage_accounts, Colors.orange, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen()));
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuBtn(String t, IconData i, Color c, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap, icon: Icon(i), label: Text(t), 
        style: ElevatedButton.styleFrom(
          backgroundColor: c, foregroundColor: Colors.white, 
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
        )
      ),
    );
  }

  Widget _buildMenuBtnSmall(String t, IconData i, Color c, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap, icon: Icon(i, size: 18), label: Text(t, style: const TextStyle(fontSize: 13)), 
      style: ElevatedButton.styleFrom(
        backgroundColor: c, foregroundColor: Colors.white, 
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
      )
    );
  }

  void _showWorkDialog() async {
  final ordersResp = await _supabase.from('orders').select('*, clients(name)').order('created_at');
  final taskTypesResp = await _supabase.from('task_types').select();

  if (!mounted) return;

  final orders = List<Map<String, dynamic>>.from(ordersResp);
  final taskTypes = List<Map<String, dynamic>>.from(taskTypesResp);

  Map<String, dynamic>? selectedOrder;
  Map<String, dynamic>? selectedTask;
  final areaController = TextEditingController();
  double currentTotal = 0;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ish Topshirish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // 1. ZAKAZNI TANLASH (Siz aytgan formatda ko'rinadi)
            DropdownButtonFormField<Map<String, dynamic>>(
              decoration: const InputDecoration(labelText: "Loyihani tanlang", border: OutlineInputBorder()),
              items: orders.map((o) => DropdownMenuItem(
                value: o, 
                child: Text("${o['project_name']}", overflow: TextOverflow.ellipsis)
              )).toList(),
              onChanged: (v) {
                setModalState(() {
                  selectedOrder = v;
                  // AVTOMATIK: Loyihachi kiritgan kvadratni yozamiz
                  areaController.text = v?['measured_area']?.toString() ?? "";
                  
                  if (selectedTask != null) {
                    currentTotal = (v?['measured_area'] ?? 0) * (selectedTask!['default_rate'] ?? 0);
                  }
                });
              },
            ),
            const SizedBox(height: 15),

            // 2. ISH TURINI TANLASH
            DropdownButtonFormField<Map<String, dynamic>>(
              decoration: const InputDecoration(labelText: "Nima ish qilindi?", border: OutlineInputBorder()),
              items: taskTypes.map((t) => DropdownMenuItem(value: t, child: Text("${t['name']}"))).toList(),
              onChanged: (v) {
                setModalState(() {
                  selectedTask = v;
                  double area = double.tryParse(areaController.text) ?? 0;
                  currentTotal = area * (v?['default_rate'] ?? 0);
                });
              },
            ),
            const SizedBox(height: 15),

            // 3. HAJM (m2) - Avtomatik to'ladi, lekin tahrirlash mumkin
            TextField(
              controller: areaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Hajm (m2)", border: OutlineInputBorder()),
              onChanged: (v) {
                setModalState(() {
                  double area = double.tryParse(v) ?? 0;
                  currentTotal = area * (selectedTask?['default_rate'] ?? 0);
                });
              },
            ),
            
            const SizedBox(height: 20),
            if (currentTotal > 0)
               Text("Hisoblangan haq: ${currentTotal.toInt()} so'm", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (selectedOrder == null || selectedTask == null) return;
                
                await _supabase.from('work_logs').insert({
                  'worker_id': _userId,
                  'order_id': selectedOrder!['id'],
                  'task_type': selectedTask!['name'],
                  'area_m2': double.tryParse(areaController.text) ?? 0,
                  'rate': selectedTask!['default_rate'],
                  'is_approved': (_userRole == 'admin' || _userRole == 'owner'),
                });
                Navigator.pop(context);
                _loadAllData();
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue.shade900),
              child: const Text("TOPSHIRISH", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ),
  );
}
}
