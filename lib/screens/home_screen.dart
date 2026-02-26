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

  // Moliyaviy ko'rsatkichlar
  double _compCash = 0; double _workDebt = 0;
  double _myEarn = 0; double _myAdv = 0;
  int _totalOrders = 0; int _activeOrders = 0;
  int _pendApps = 0; int _totalClients = 0;

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
      final profile = await _supabase.from('profiles').select('*, app_roles(*)').eq('id', user!.id).single();
      
      _userName = profile['full_name'] ?? 'Foydalanuvchi';
      _isSuperAdmin = profile['is_super_admin'] ?? false;
      _userRoleType = profile['app_roles']?['role_type'] ?? 'worker';

      // 1. Korxona moliya (Admin uchun)
      final orders = await _supabase.from('orders').select('total_price, status');
      final withdrawals = await _supabase.from('withdrawals').select('amount, status');
      final workLogs = await _supabase.from('work_logs').select('total_sum, is_approved');

      double rev = 0; for (var o in orders) rev += (o['total_price'] ?? 0).toDouble();
      double paid = 0; for (var w in withdrawals) if (w['status'] == 'approved') paid += (w['amount'] ?? 0).toDouble();
      double totalEarned = 0; for (var l in workLogs) if (l['is_approved']) totalEarned += (l['total_sum'] ?? 0).toDouble();

      // 2. Shaxsiy moliya
      final myL = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id).eq('is_approved', true);
      final myW = await _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved');
      
      double myE = 0; for (var ml in myL) myE += (ml['total_sum'] ?? 0).toDouble();
      double myA = 0; for (var mw in myW) myA += (mw['amount'] ?? 0).toDouble();

      setState(() {
        _compCash = rev - paid;
        _workDebt = totalEarned - paid;
        _myEarn = myE; _myAdv = myA;
        _totalOrders = orders.length;
        _activeOrders = orders.where((o) => ['pending','material','assembly','delivery'].contains(o['status'])).length;
        _pendApps = (workLogs.where((l) => !l['is_approved']).length) + (withdrawals.where((w) => w['status'] == 'pending').length);
      });
    } catch (e) { debugPrint("Xato: $e"); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }
bool _hasPerm(String p) => _isSuperAdmin || (true); // Soddalashtirilgan ruxsat

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
          onRefresh: _loadAllData,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              HomeHeader(greeting: "Xush kelibsiz", userName: _userName),
              const SizedBox(height: 25),
              
              // BALANSCARD - Endi hamma narsa alohida uzatildi!
              BalanceCard(
                role: _userRoleType,
                companyBalance: _compCash,
                totalWorkerDebt: _workDebt,
                personalEarnings: _myEarn,
                personalAdvances: _myAdv,
                statsCount: _totalOrders,
              ),
              const SizedBox(height: 25),

              // ISH TOPSHIRISH TUGMASI (Mana qaytib keldi!)
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E5BFF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  icon: const Icon(Icons.add_task), label: const Text("BAJARILGAN ISHNI TOPSHIRISH", style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWorkLogScreen())).then((_) => _loadAllData()),
                ),
              ),
              const SizedBox(height: 25),

              HomeActionGrid(
                isAdmin: _userRoleType == 'aup',
                canManageUsers: _isSuperAdmin,
                totalOrders: _totalOrders, activeOrders: _activeOrders,
                pendingApprovalsCount: _pendApps,
                totalClientsCount: 0, newClientsCount: 0,
                showWithdrawOption: _userRoleType == 'worker',
                onWithdrawTap: () {}, // Oldingi dialog chaqiriladi
                onClientsTap: () => Navigator.pushNamed(context, '/clients').then((_) => _loadAllData()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}