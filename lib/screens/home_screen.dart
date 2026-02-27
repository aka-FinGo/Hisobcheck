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
import 'orders_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
@@ -54,48 +20,42 @@ class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // --- Yangi Ruxsatlar Tizimi O'zgaruvchilari ---
  // --- Ruxsatlar va Profil ---
  bool _isSuperAdmin = false;
  String _userName = '';
  String _userRoleType = 'worker'; 
  String _positionName = 'Hodim';  
  
  Map<String, dynamic> _customPermissions = {};
  Map<String, dynamic> _rolePermissions = {};

  // --- Kassa va Statistika ---
  // --- Kassa va Statistika o'zgaruvchilari ---
  double _displayEarned = 0;
  double _displayWithdrawn = 0;
  double _secondaryBalance = 0; 
  int _statsCount = 0;
  int _totalOrders = 0;
  int _activeOrders = 0;

  // RAHBAR UCHUN KUTILAYOTGAN TASDIQLAR SONI
  int _pendingApprovals = 0;
  // --- Bildirishnomalar (Badge) soni ---
  int _pendingApprovals = 0; // Tasdiqlashlar uchun
  int _totalClientsCount = 0; // Jami mijozlar
  int _newClientsCount = 0;   // Yangi mijozlar (+1)

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // ─── 1. RUXSATLARNI TEKSHIRUVCHI FUNKSIYA ──────────────
  // Ruxsatlarni tekshirish mantiqi
  bool hasPermission(String action) {
    if (_isSuperAdmin) return true; 
    
    if (_customPermissions.containsKey(action)) {
      return _customPermissions[action] == true;
    }
    
    if (_rolePermissions.containsKey(action)) {
      return _rolePermissions[action] == true;
    }
    
    if (_customPermissions.containsKey(action)) return _customPermissions[action] == true;
    if (_rolePermissions.containsKey(action)) return _rolePermissions[action] == true;
    return false; 
  }

  // ─── 2. MA'LUMOT VA RUXSATLARNI BAZADAN TORTISH ───────────────
  // MA'LUMOTLARNI YUKLASH (SUPABASE)
  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
@@ -120,170 +80,101 @@ class _HomeScreenState extends State<HomeScreen> {
        _rolePermissions = profile['app_roles']['permissions'] ?? {};
      }

      // ADMIN VA AUP UCHUN MA'LUMOTLAR
      if (hasPermission('can_view_finance') || _isSuperAdmin) {
        // AUP / ADMIN MANTIQI
        // 1. Zakazlar statistikasi
        final orders = await _supabase.from('orders').select('total_price, status');
        final withdrawals = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');
            
        double totalIncome = 0;
        double totalPaid = 0;
        int active = 0;
        
        // 2. Kutilayotgan tasdiqlar (Ishlar + Avanslar)
        final pendingWorks = await _supabase.from('work_logs').select('id').eq('is_approved', false);
        final pendingAvans = await _supabase.from('withdrawals').select('id').eq('status', 'pending');
        // 3. Mijozlar (+1 mantiqi bilan)
        final clientsRes = await _supabase.from('clients').select('id, created_at');

        double totalInc = 0; int active = 0;
        for (var o in orders) {
          totalIncome += (o['total_price'] ?? 0).toDouble();
          if (OrderStatus.activeStatuses.contains(o['status'])) {
             active++;
          }
          totalInc += (o['total_price'] ?? 0).toDouble();
          if (['pending', 'material', 'assembly', 'delivery'].contains(o['status'])) active++;
        }
        for (var w in withdrawals) totalPaid += (w['amount'] ?? 0).toDouble();

        final workers = await _supabase.from('profiles').select('id').eq('is_super_admin', false);
        final allWorks = await _supabase.from('work_logs').select('total_sum').eq('is_approved', true);
        
        double totalWorksSum = 0;
        for (var w in allWorks) totalWorksSum += (w['total_sum'] ?? 0).toDouble();
        // Oxirgi 24 soat ichida qo'shilgan mijozlarni aniqlash
        final dayAgo = DateTime.now().subtract(const Duration(days: 1));
        final recentOnes = clientsRes.where((c) => DateTime.parse(c['created_at']).isAfter(dayAgo)).length;

        // Kutilayotgan tasdiqlarni sanash (Avanslar + Ishlar)
        final pendingWorks = await _supabase.from('work_logs').select('id').eq('is_approved', false);
        final pendingWithdrawals = await _supabase.from('withdrawals').select('id').eq('status', 'pending');
        
        if (mounted) {
          setState(() {
            _displayEarned = totalIncome;
            _displayWithdrawn = totalPaid;
            _displayEarned = totalInc;
            _totalOrders = orders.length;
            _activeOrders = active;
            _secondaryBalance = (totalWorksSum - totalPaid) > 0 ? (totalWorksSum - totalPaid) : 0; 
            _statsCount = workers.length; 
            _pendingApprovals = pendingWorks.length + pendingWithdrawals.length; // Raqamni hisobladik!
            _pendingApprovals = pendingWorks.length + pendingAvans.length; // Haqiqiy son ulandi!
            _totalClientsCount = clientsRes.length;
            _newClientsCount = recentOnes; // +1 mantiqi
          });
        }
      } else {
        // WORKER MANTIQI
        // ODDIY ISHCHI UCHUN MA'LUMOTLAR
        final works = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id).eq('is_approved', true);
        final withdraws = await _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved');
            
        double earned = 0;
        double paid = 0;
        double earned = 0; double paid = 0;
        for (var w in works) earned += (w['total_sum'] ?? 0).toDouble();
        for (var w in withdraws) paid += (w['amount'] ?? 0).toDouble();

        if (mounted) {
          setState(() {
            _displayEarned = earned;
            _displayWithdrawn = paid;
            _secondaryBalance = earned - paid; 
            _statsCount = works.length; 
            _pendingApprovals = 0; // Oddiy ishchi uchun bu kerak emas
            _secondaryBalance = earned - paid;
            _pendingApprovals = 0;
          });
        }
      }
    } catch (e) {
      debugPrint("Yuklashda xato: $e");
      debugPrint("Xato: $e");
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
// AVANS SO'RASH DIALOGI
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
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Avans so'rash"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Summa")),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Sababi (ixtiyoriy)")),
            ],
          );
        },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor")),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                setDialogState(() => isSubmitting = true);
                try {
                  await _supabase.from('withdrawals').insert({
                    'worker_id': _supabase.auth.currentUser!.id,
                    'amount': double.tryParse(amountCtrl.text) ?? 0,
                    'description': descCtrl.text,
                    'status': 'pending'
                  });
                  Navigator.pop(ctx);
                  _loadAllData();
                } finally {
                  setDialogState(() => isSubmitting = false);
                }
              },
              child: const Text("Yuborish"),
            ),
          ],
        ),
      ),
    );
  }
@@ -292,66 +183,62 @@ class _HomeScreenState extends State<HomeScreen> {
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
        child: _isLoading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
          onRefresh: _loadAllData,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 1. SALOMLASHISH
              HomeHeader(greeting: "Xush kelibsiz", userName: _userName),
              const SizedBox(height: 25),
              
              // 2. KASSA KARTASI
              BalanceCard(
                role: (_isSuperAdmin || hasPermission('can_view_finance')) ? 'admin' : 'worker',
                mainBalance: _displayEarned - _displayWithdrawn,
                income: _displayEarned, expense: _displayWithdrawn,
                secondaryBalance: _secondaryBalance, statsCount: _statsCount,
              ),
              const SizedBox(height: 25),

              // 3. ISH TOPSHIRISH TUGMASI
              if (hasPermission('can_add_work_log')) ...[
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E5BFF), 
                      foregroundColor: Colors.white, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                  ],
                    icon: const Icon(Icons.add_task), label: const Text("Ishni topshirish", style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWorkLogScreen())).then((_) => _loadAllData()),
                  ),
                ),
                const SizedBox(height: 25),
              ],

              // 4. TEZKOR TUGMALAR GRIDI
              HomeActionGrid(
                isAdmin: _isSuperAdmin || _userRoleType == 'aup',
                canManageUsers: _isSuperAdmin || hasPermission('can_manage_users'),
                totalOrders: _totalOrders, 
                activeOrders: _activeOrders,
                pendingApprovalsCount: _pendingApprovals,
                totalClientsCount: _totalClientsCount,
                newClientsCount: _newClientsCount,
                showWithdrawOption: _userRoleType == 'worker',
                onWithdrawTap: _showWithdrawDialog,
                onClientsTap: () {
                  // Mijozlar sahifasiga o'tish va badge'ni o'chirish
                  setState(() => _newClientsCount = 0);
                  Navigator.pushNamed(context, '/clients').then((_) => _loadAllData());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
}
