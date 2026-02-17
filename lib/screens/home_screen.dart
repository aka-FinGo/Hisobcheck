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
    // Faqat 'pending' yoki 'in_progress' zakazlarni olamiz (yopilgan zakazga ish qo'shib bo'lmaydi)
    final ordersResp = await _supabase
        .from('orders')
        .select('*, clients(full_name)')
        .neq('status', 'completed') 
        .neq('status', 'canceled')
        .order('created_at', ascending: false);
        
    final taskTypesResp = await _supabase.from('task_types').select();

    if (!mounted) return;

    final orders = List<Map<String, dynamic>>.from(ordersResp);
    final taskTypes = List<Map<String, dynamic>>.from(taskTypesResp);

    dynamic selectedOrder;
    Map<String, dynamic>? selectedTask;
    final areaController = TextEditingController(); // Kvadrat avtomatik yoziladi
    final notesController = TextEditingController(); // Ishchi o'zidan izoh qo'shishi mumkin
    double currentTotal = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Ish Topshirish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // 1. ZAKAZNI TANLASH (Eng muhim joyi)
              DropdownButtonFormField<dynamic>(
                decoration: const InputDecoration(
                  labelText: "Qaysi zakazda ishladingiz?", 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder_shared)
                ),
                isExpanded: true,
                items: orders.map((o) => DropdownMenuItem<dynamic>(
                  value: o, 
                  // Ekranda: "100_01_Ali... (15.5 m2)" deb chiqadi
                  child: Text("${o['project_name']} (${o['total_area_m2']} m²)", overflow: TextOverflow.ellipsis)
                )).toList(),
                onChanged: (v) {
                  setModalState(() {
                    selectedOrder = v;
                    // AVTOMATIK TO'LDIRISH:
                    // Loyihachi yozgan kvadratni olib kelib qo'yamiz
                    areaController.text = (v['total_area_m2'] ?? 0).toString();
                    
                    // Agar ish turi tanlangan bo'lsa, narxni qayta hisoblaymiz
                    if (selectedTask != null) {
                       double area = double.tryParse(areaController.text) ?? 0;
                       currentTotal = area * (selectedTask!['default_rate'] ?? 0);
                    }
                  });
                },
              ),
              const SizedBox(height: 15),

              // 2. ISH TURINI TANLASH
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(labelText: "Nima ish qilindi?", border: OutlineInputBorder(), prefixIcon: Icon(Icons.handyman)),
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

              // 3. KVADRAT (Avtomatik to'ladi, lekin o'zgartirsa ham bo'ladi)
              TextField(
                controller: areaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Hajm (m²)", 
                  border: OutlineInputBorder(),
                  helperText: "Zakazdan avtomatik olindi (o'zgartirish mumkin)"
                ),
                onChanged: (v) {
                  setModalState(() {
                    double area = double.tryParse(v) ?? 0;
                    currentTotal = area * (selectedTask?['default_rate'] ?? 0);
                  });
                },
              ),
              const SizedBox(height: 10),
              
              if (currentTotal > 0)
                 Container(
                   padding: const EdgeInsets.all(10),
                   decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                   child: Row(
                     children: [
                       const Icon(Icons.monetization_on, color: Colors.green),
                       const SizedBox(width: 10),
                       Text("Tahminiy ish haqi: ${currentTotal.toInt()} so'm", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                     ],
                   ),
                 ),

              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedOrder == null || selectedTask == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Zakaz va Ish turini tanlang!")));
                      return;
                    }
                    
                    await _supabase.from('work_logs').insert({
                      'worker_id': _supabase.auth.currentUser!.id,
                      'order_id': selectedOrder['id'],
                      'task_type': selectedTask!['name'],
                      'area_m2': double.tryParse(areaController.text) ?? 0,
                      'rate': selectedTask!['default_rate'],
                      'total_sum': currentTotal,
                      'description': notesController.text, // Agar izoh yozgan bo'lsa
                      'is_approved': false, // Admin tasdiqlashi kerak
                    });
                    
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ish topshirildi! Admin tasdiqlashini kuting."), backgroundColor: Colors.green));
                      // Bu yerda _loadAllData() chaqirilishi kerak (agar parentda bo'lsa)
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                  child: const Text("ISHNI TOPSHIRISH"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
