import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'admin_approvals.dart';
import 'add_withdrawal.dart';
import 'manage_users_screen.dart';
import 'clients_screen.dart';
import 'stats_screen.dart';
import 'user_profile_screen.dart'; // Profilga o'tish uchun
import '../widgets/balance_card.dart';

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
// Davomi pastda...
// ...Yuqoridagi kodning davomi

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade900,
        title: const Text("Aristokrat Mebel", style: TextStyle(color: Colors.white)),
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
// Davomi pastda...
// ...Yuqoridagi kodning davomi

  void _showWorkDialog() async {
    final ordersResp = await _supabase.from('orders').select().order('created_at');
    final taskTypesResp = await _supabase.from('task_types').select();

    if (!mounted) return;

    final orders = List<Map<String, dynamic>>.from(ordersResp);
    final taskTypes = List<Map<String, dynamic>>.from(taskTypesResp);

    String? selectedOrderId;
    Map<String, dynamic>? selectedTask;
    final areaController = TextEditingController();
    final descController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                const Text("Ish topshirish", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Qaysi zakaz?", border: OutlineInputBorder()),
                  items: orders.map((o) {
                    String label = "${o['order_number']}";
                    if (o['client_name'] != null && o['client_name'].toString().isNotEmpty) {
                      label += " - ${o['client_name']}";
                    }
                    return DropdownMenuItem(value: o['id'].toString(), child: Text(label));
                  }).toList(),
                  onChanged: (v) => setModalState(() => selectedOrderId = v),
                ),
                const SizedBox(height: 15),

                DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: const InputDecoration(labelText: "Nima ish qildingiz?", border: OutlineInputBorder()),
                  items: taskTypes.map((t) => DropdownMenuItem(value: t, child: Text("${t['name']}"))).toList(),
                  onChanged: (v) => setModalState(() => selectedTask = v),
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: areaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: "Hajmi (m2 yoki dona)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: "Izoh (ixtiyoriy)", border: OutlineInputBorder(), hintText: "Masalan: Oshxona"),
                ),
                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : () async {
                      if (selectedOrderId == null || selectedTask == null || areaController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("To'ldirish shart!")));
                        return;
                      }
                      setModalState(() => isSubmitting = true);
                      try {
                        double area = double.tryParse(areaController.text.replaceAll(',', '.')) ?? 0;
                        double rate = (selectedTask!['default_rate'] ?? 0).toDouble();

                        await _supabase.from('work_logs').insert({
                          'worker_id': _userId,
                          'order_id': int.parse(selectedOrderId!),
                          'task_type': selectedTask!['name'],
                          'area_m2': area,
                          'rate': rate,
                          'total_sum': area * rate,
                          'description': descController.text,
                          'is_approved': (_userRole == 'admin' || _userRole == 'owner'),
                          'approved_by': (_userRole == 'admin' || _userRole == 'owner') ? _userId : null,
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          _loadAllData();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Saqlandi!")));
                        }
                      } catch (e) {
                        setModalState(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text("Xato: $e")));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                    child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("TOPSHIRISH"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}