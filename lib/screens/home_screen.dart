import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/home_header.dart';
import '../widgets/balance_card.dart';
import '../widgets/home_action_grid.dart';
import 'add_work_log_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  String _userName = '';
  String _userRoleType = 'worker';
  bool _isSuperAdmin = false;
  Map<String, dynamic> _cPerms = {};

  // Moliyaviy o'zgaruvchilar
  double _cCash = 0; double _wDebt = 0;
  double _pEarn = 0; double _pPaid = 0;
  
  int _tOrd = 0; int _aOrd = 0;
  int _pApp = 0; int _tClients = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  bool hasPerm(String p) => _isSuperAdmin || _cPerms[p] == true;

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      final prof = await _supabase.from('profiles').select('*, app_roles(*)').eq('id', user!.id).single();
      
      _userName = prof['full_name'] ?? 'Admin';
      _isSuperAdmin = prof['is_super_admin'] ?? false;
      _cPerms = prof['custom_permissions'] ?? {};
      _userRoleType = prof['app_roles']?['role_type'] ?? 'worker';

      // 1. GLOBAL MOLIYA (Schema bo'yicha)
      final orders = await _supabase.from('orders').select('total_price, status');
      final withs = await _supabase.from('withdrawals').select('amount, status');
      final logs = await _supabase.from('work_logs').select('total_sum, is_approved');
      final clients = await _supabase.from('clients').select('id');

      double rev = 0; for (var o in orders) rev += (o['total_price'] ?? 0).toDouble();
      double paid = 0; for (var w in withs) if (w['status'] == 'approved') paid += (w['amount'] ?? 0).toDouble();
      double earned = 0; for (var l in logs) if (l['is_approved']) earned += (l['total_sum'] ?? 0).toDouble();

      // 2. SHAXSIY MOLIYA
      final myL = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id).eq('is_approved', true);
      final myW = await _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved');
      double myE = 0; for (var ml in myL) myE += (ml['total_sum'] ?? 0).toDouble();
      double myP = 0; for (var mw in myW) myP += (mw['amount'] ?? 0).toDouble();

      setState(() {
        _cCash = rev - paid; _wDebt = earned - paid;
        _pEarn = myE; _pPaid = myP;
        _tOrd = orders.length; _tClients = clients.length;
        _aOrd = orders.where((o) => ['pending','material','assembly','delivery'].contains(o['status'])).length;
        _pApp = (logs.where((l) => !l['is_approved']).length) + (withs.where((w) => w['status'] == 'pending').length);
      });
    } catch (e) { debugPrint("Xato: $e"); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
          onRefresh: _loadAllData,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              HomeHeader(greeting: "Assalomu alaykum", userName: _userName),
              const SizedBox(height: 25),
              
              // BALANSCARD - Parametrlar to'g'rilandi!
              BalanceCard(
                role: _userRoleType,
                companyCash: _cCash,
                workerDebt: _wDebt,
                personalEarned: _pEarn,
                personalPaid: _pPaid,
                statsCount: _tOrd,
              ),
              const SizedBox(height: 30),

              // ISH TOPSHIRISH TUGMASI (PULT!)
              if (hasPerm('can_add_work_log'))
                SizedBox(
                  width: double.infinity, height: 60,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E5BFF), foregroundColor: Colors.white, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text("ISH TOPSHIRISH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWorkLogScreen())).then((_) => _loadAllData()),
                  ),
                ),
              const SizedBox(height: 30),

              // ACTION GRID - Parametrlar to'g'rilandi!
              HomeActionGrid(
                isAdmin: _isSuperAdmin || _userRoleType == 'aup',
                canManageUsers: _isSuperAdmin || hasPerm('can_manage_users'),
                totalOrders: _tOrd, 
                activeOrders: _aOrd,
                pendingApprovalsCount: _pApp,
                totalClientsCount: _tClients, // XATOLIK YO'QOLDI
                newClientsCount: 0,
                showWithdrawOption: _userRoleType == 'worker',
                onWithdrawTap: () {}, // Dialog mantiqi ulanadi
                onClientsTap: () => Navigator.pushNamed(context, '/clients').then((_) => _loadAllData()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}