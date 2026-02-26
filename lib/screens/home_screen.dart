import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// O'zimiz yozgan widjetlarni chaqiramiz
import '../widgets/home_header.dart';
import '../widgets/balance_card.dart';
import '../widgets/home_action_grid.dart';
import 'add_work_log_screen.dart'; 

class OrderStatus {
  static const pending = 'pending';
  static const material = 'material';
  static const assembly = 'assembly';
  static const delivery = 'delivery';
  static const completed = 'completed';
  static const canceled = 'canceled';

  static String getText(String? status) {
    switch (status) {
      case pending: return 'Kutilmoqda';
      case material: return 'Kesish/Material';
      case assembly: return "Yig'ish";
      case delivery: return "O'rnatish";
      case completed: return 'Yakunlandi';
      case canceled: return 'Bekor qilindi';
      default: return "Noma'lum"; // Tutuq belgisi xato bermasligi uchun ikkitalik qo'shtirnoq
    }
  }

  static Color getColor(String? status) {
    switch (status) {
      case pending: return Colors.orange;
      case material: return Colors.purple;
      case assembly: return Colors.blue;
      case delivery: return Colors.teal;
      case completed: return Colors.green;
      case canceled: return Colors.red;
      default: return Colors.grey;
    }
  }
  
  static const activeStatuses = [pending, material, assembly, delivery];
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // --- Yangi Ruxsatlar Tizimi O'zgaruvchilari ---
  bool _isSuperAdmin = false;
  String _userName = '';
  String _userRoleType = 'worker'; 
  String _positionName = 'Hodim';  
  
  Map<String, dynamic> _customPermissions = {};
  Map<String, dynamic> _rolePermissions = {};

  // --- Kassa va Statistika ---
  double _displayEarned = 0;
  double _displayWithdrawn = 0;
  double _secondaryBalance = 0; 
  int _statsCount = 0;
  int _totalOrders = 0;
  int _activeOrders = 0;
  
  // RAHBAR UCHUN KUTILAYOTGAN TASDIQLAR SONI
  int _pendingApprovals = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // ─── 1. RUXSATLARNI TEKSHIRUVCHI FUNKSIYA ──────────────
  bool hasPermission(String action) {
    if (_isSuperAdmin) return true; 
    
    if (_customPermissions.containsKey(action)) {
      return _customPermissions[action] == true;
    }
    
    if (_rolePermissions.containsKey(action)) {
      return _rolePermissions[action] == true;
    }
    
    return false; 
  }

  // ─── 2. MA'LUMOT VA RUXSATLARNI BAZADAN TORTISH ───────────────
  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('*, app_roles(name, role_type, permissions)')
          .eq('id', user.id)
          .single();

      _userName = profile['full_name'] ?? 'Foydalanuvchi';
      _isSuperAdmin = profile['is_super_admin'] ?? false;
      _customPermissions = profile['custom_permissions'] ?? {};
      
      if (profile['app_roles'] != null) {
        _positionName = profile['app_roles']['name'] ?? 'Hodim';
        _userRoleType = profile['app_roles']['role_type'] ?? 'worker';
        _rolePermissions = profile['app_roles']['permissions'] ?? {};
      }

      if (hasPermission('can_view_finance') || _isSuperAdmin) {
        // AUP / ADMIN MANTIQI
        final orders = await _supabase.from('orders').select('total_price, status');
        final withdrawals = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');
            
        double totalIncome = 0;
        double totalPaid = 0;
        int active = 0;
        
        for (var o in orders) {
          totalIncome += (o['total_price'] ?? 0).toDouble();
          if (OrderStatus.activeStatuses.contains(o['status'])) {
             active++;
          }
        }
        for (var w in withdrawals) totalPaid += (w['amount'] ?? 0).toDouble();

        final workers = await _supabase.from('profiles').select('id').eq('is_super_admin', false);
        final allWorks = await _supabase.from('work_logs').select('total_sum').eq('is_approved', true);
        
        double totalWorksSum = 0;
        for (var w in allWorks) totalWorksSum += (w['total_sum'] ?? 0).toDouble();

        // Kutilayotgan tasdiqlarni sanash (Avanslar + Ishlar)
        final pendingWorks = await _supabase.from('work_logs').select('id').eq('is_approved', false);
        final pendingWithdrawals = await _supabase.from('withdrawals').select('id').eq('status', 'pending');
        
        if (mounted) {
          setState(() {
            _displayEarned = totalIncome;
            _displayWithdrawn = totalPaid;
            _totalOrders = orders.length;
            _activeOrders = active;
            _secondaryBalance = (totalWorksSum - totalPaid) > 0 ? (totalWorksSum - totalPaid) : 0; 
            _statsCount = workers.length; 
            _pendingApprovals = pendingWorks.length + pendingWithdrawals.length; // Raqamni hisobladik!
          });
        }
      } else {
        // WORKER MANTIQI
        final works = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id).eq('is_approved', true);
        final withdraws = await _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved');
            
        double earned = 0;
        double paid = 0;
        for (var w in works) earned += (w['total_sum'] ?? 0).toDouble();
        for (var w in withdraws) paid += (w['amount'] ?? 0).toDouble();
        
        if (mounted) {
          setState(() {
            _displayEarned = earned;
            _displayWithdrawn = paid;
            _secondaryBalance = earned - paid; 
            _statsCount = works.length; 
            _pendingApprovals = 0; // Oddiy ishchi uchun bu kerak emas
          });
        }
      }
    } catch (e) {
      debugPrint("Yuklashda xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return "Xayrli tong";
    if (h < 17) return "Xayrli kun";
    return "Xayrli kech";
  }

  // ─── 3. AVANS SO'RASH FORMASI ─────────
  void _showWithdrawDialog() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.orange),
                SizedBox(width: 10),
                Text("Avans so'rash"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Sizning so'rovingiz rahbar tomonidan tasdiqlangach, balansingizdan yechiladi va hisoblanadi.", 
                  style: TextStyle(fontSize: 12, color: Colors.grey)
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Summa (so'm)", 
                    border: OutlineInputBorder(), 
                    prefixIcon: Icon(Icons.money, color: Colors.green)
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Sababi (ixtiyoriy)", 
                    border: OutlineInputBorder(), 
                    prefixIcon: Icon(Icons.edit_note)
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx), 
                child: const Text("Bekor qilish", style: TextStyle(color: Colors.grey))
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                onPressed: isSubmitting ? null : () async {
                  final amountText = amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                  final amount = double.tryParse(amountText) ?? 0;
                  
                  if (amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Iltimos, to'g'ri summa kiriting!"), backgroundColor: Colors.redAccent));
                    return;
                  }
                  
                  setDialogState(() => isSubmitting = true);
                  try {
                    await _supabase.from('withdrawals').insert({
                      'worker_id': _supabase.auth.currentUser!.id,
                      'amount': amount,
                      'description': descCtrl.text.trim(),
                      'status': 'pending', 
                    });
                    
                    if (mounted) {
                      Navigator.pop(ctx);
                      _loadAllData(); // Jo'natgandan keyin ekran yangilanadi
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Avans so'rovi yuborildi! Rahbar tasdig'i kutilmoqda."), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
                  } finally {
                    setDialogState(() => isSubmitting = false);
                  }
                },
                child: isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("Yuborish"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAllData,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  children: [
                    HomeHeader(greeting: _greeting, userName: "$_userName ($_positionName)"),
                    const SizedBox(height: 25),
                    
                    BalanceCard(
                      role: (hasPermission('can_view_finance') || _isSuperAdmin) ? 'admin' : 'worker', 
                      mainBalance: _displayEarned - _displayWithdrawn,
                      income: _displayEarned,
                      expense: _displayWithdrawn, 
                      secondaryBalance: _secondaryBalance, 
                      statsCount: _statsCount, 
                    ),
                    const SizedBox(height: 25),

                    // ISH TOPSHIRISH TUGMASI (Hodimlar uchun)
                    if (hasPermission('can_add_work_log')) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E5BFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 3,
                          ),
                          icon: const Icon(Icons.add_task_rounded, size: 26),
                          label: const Text("Bajargan ishni topshirish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (_) => const AddWorkLogScreen())
                            ).then((value) {
                              _loadAllData();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 25),
                    ],
                    
                    // TEZKOR TUGMALAR GRID'I (Bu yerga Badge ulandi)
                    HomeActionGrid(
                      isAdmin: _isSuperAdmin || _userRoleType == 'aup',
                      canManageUsers: _isSuperAdmin || hasPermission('can_manage_users'),
                      totalOrders: _totalOrders,
                      activeOrders: _activeOrders,
                      pendingApprovalsCount: _pendingApprovals, // ULANDI!
                      onWithdrawTap: _showWithdrawDialog,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
