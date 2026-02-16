// home_screen.dart fayli uchun to'liq yangilangan kod
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'admin_approvals.dart';
import 'add_withdrawal.dart';
import 'manage_users_screen.dart';
import 'clients_screen.dart';
import '../widgets/balance_card.dart';
import 'stats_screen.dart'; // StatsScreen sahifasini HomeScreen'ga tanitish
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

      // Faqat o'ziga tegishli va tasdiqlangan ishlarni yuklash
      final workLogs = await _supabase.from('work_logs')
          .select('total_sum')
          .eq('worker_id', _userId)
          .eq('is_approved', true);

      // Faqat o'zi olgan pullarni yuklash
      final withdrawals = await _supabase.from('withdrawals')
          .select('amount')
          .eq('worker_id', _userId);

      double earned = 0, withdrawn = 0;
      for (var log in workLogs) earned += (log['total_sum'] ?? 0).toDouble();
      for (var w in withdrawals) withdrawn += (w['amount'] ?? 0).toDouble();

      if (mounted) {
        setState(() {
          _userName = profile['full_name'] ?? 'Xodim';
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
        title: Text("Aristokrat Mebel", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(onPressed: _loadAllData, icon: const Icon(Icons.refresh, color: Colors.white)),
          IconButton(
            onPressed: () async {
              await _supabase.auth.signOut();
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Yangilangan BalanceCard
            BalanceCard(
              earned: _totalEarned, 
              withdrawn: _totalWithdrawn,
              role: _userRole,
              onStatsTap: () {
                // Bu yerda umumiy sex statistikasi sahifasiga o'tamiz
               Navigator.push(
					  context, 
					  MaterialPageRoute(builder: (_) => const StatsScreen())
				  );
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 25, left: 25, right: 25, top: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Ishni Kiritish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 25),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Zakazni tanlang", border: OutlineInputBorder()),
                items: orders.map((o) => DropdownMenuItem(value: o['id'].toString(), child: Text("${o['order_number']}"))).toList(),
                onChanged: (v) {
                  selectedOrderId = v;
                  final selectedOrder = orders.firstWhere((o) => o['id'].toString() == v);
                  setModalState(() => areaController.text = selectedOrder['total_area_m2']?.toString() ?? "0");
                },
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(labelText: "Ish turi", border: OutlineInputBorder()),
                items: taskTypes.map((t) => DropdownMenuItem(value: t, child: Text("${t['name']}"))).toList(),
                onChanged: (v) => setModalState(() => selectedTask = v),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () async {
                  if (selectedOrderId == null || selectedTask == null) return;
                  
                  double area = double.tryParse(areaController.text) ?? 0;
                  double rate = (selectedTask!['default_rate'] ?? 0).toDouble();
                  
                  await _supabase.from('work_logs').insert({
                    'worker_id': _userId,
                    'order_id': int.parse(selectedOrderId!),
                    'task_type': selectedTask!['name'],
                    'area_m2': area,
                    'rate': rate,
                    'total_sum': area * rate,
                    // Admin yoki Owner o'z ishini o'zi tasdiqlaydi
                    'is_approved': (_userRole == 'admin' || _userRole == 'owner'),
                    'approved_by': (_userRole == 'admin' || _userRole == 'owner') ? _userId : null,
                  });
                  if (mounted) { Navigator.pop(context); _loadAllData(); }
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                child: const Text("SAQLASH"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
