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

  // Profil va Role (Schema bo'yicha position_id orqali)
  bool _isSuperAdmin = false;
  String _userName = '';
  String _uRoleType = 'worker'; 
  Map<String, dynamic> _cPerms = {}; // Custom Permissions

  // Global Moliya (Superadmin uchun)
  double _compCash = 0;   // Jami tushum - Jami chiqim
  double _wDebt = 0;      // Ishchilardan jami qarz
  double _myEarn = 0;     // Shaxsiy maosh (WorkLogs)
  double _myPaid = 0;     // Shaxsiy avanslar (Withdrawals)
  
  int _tOrders = 0; int _aOrders = 0;
  int _pApps = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // RUHSATLARNI TEKSHIRISH (Schema bo'yicha custom_permissions va is_super_admin)
  bool hasPerm(String p) {
    if (_isSuperAdmin) return true;
    return _cPerms[p] == true;
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      // profiles va app_roles jadvallarini JOIN qilib olish
      final prof = await _supabase.from('profiles').select('*, app_roles(*)').eq('id', user!.id).single();
      
      _userName = prof['full_name'] ?? 'Admin';
      _isSuperAdmin = prof['is_super_admin'] ?? false;
      _cPerms = prof['custom_permissions'] ?? {};
      _uRoleType = prof['app_roles']?['role_type'] ?? 'worker';

      // 1. KORXONA KASSASI: orders.total_price - withdrawals.amount(approved)
      final oRes = await _supabase.from('orders').select('total_price, status');
      final wRes = await _supabase.from('withdrawals').select('amount, status').eq('status', 'approved');
      final lRes = await _supabase.from('work_logs').select('total_sum, is_approved');

      double rev = 0; for (var o in oRes) rev += (o['total_price'] ?? 0).toDouble();
      double paid = 0; for (var w in wRes) paid += (w['amount'] ?? 0).toDouble();
      double earned = 0; for (var l in lRes) if (l['is_approved']) earned += (l['total_sum'] ?? 0).toDouble();

      // 2. SHAXSIY MOLIYA (Mening ishlarim va avanslarim)
      final myL = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id).eq('is_approved', true);
      final myW = await _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved');
      
      double myE = 0; for (var ml in myL) myE += (ml['total_sum'] ?? 0).toDouble();
      double myP = 0; for (var mw in myW) myP += (mw['amount'] ?? 0).toDouble();

      setState(() {
        _compCash = rev - paid;
        _wDebt = earned - paid;
        _myEarn = myE; _myPaid = myP;
        _tOrders = oRes.length;
        _aOrders = oRes.where((o) => ['pending','material','assembly','delivery'].contains(o['status'])).length;
        _pApps = (lRes.where((l) => !l['is_approved']).length) + (wRes.where((w) => w['status'] == 'pending').length);
      });
    } catch (e) { debugPrint("Xato: $e"); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              HomeHeader(greeting: "Assalomu alaykum", userName: _userName),
              const SizedBox(height: 25),
              
              // BALANSCARD (Kassa, Qarz va Shaxsiy hisob bittada)
              BalanceCard(
                role: _uRoleType,
                companyCash: _compCash,
                workerDebt: _wDebt,
                personalEarned: _myEarn,
                personalPaid: _myPaid,
                statsCount: _tOrders,
              ),
              const SizedBox(height: 30),

              // ISH TOPSHIRISH TUGMASI (Endi ruxsat bo'lsa srazu chiqadi!)
              if (hasPerm('can_add_work_log'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: SizedBox(
                    width: double.infinity, height: 60,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E5BFF), 
                        foregroundColor: Colors.white, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 6,
                      ),
                      icon: const Icon(Icons.add_task_rounded, size: 28),
                      label: const Text("ISH TOPSHIRISH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWorkLogScreen())).then((_) => _loadData()),
                    ),
                  ),
                ),

              // TEZKOR TUGMALAR (Admin uchun hamma narsa ochiq)
              HomeActionGrid(
                isAdmin: _isSuperAdmin || _uRoleType == 'aup',
                canManageUsers: _isSuperAdmin || hasPerm('can_manage_users'),
                totalOrders: _tOrders, 
                activeOrders: _aOrders,
                pendingApprovalsCount: _pApps,
                onWithdrawTap: () {}, // Oldingi dialog mantiqi ulanadi
                onClientsTap: () => Navigator.pushNamed(context, '/clients').then((_) => _loadData()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}