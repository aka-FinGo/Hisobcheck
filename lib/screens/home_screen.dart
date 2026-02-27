import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// ─── Ekranlar ─────────────────────────────────────────────
import 'clients_screen.dart';
import 'stats_screen.dart';
import 'orders_list_screen.dart';
import 'user_profile_screen.dart';
import 'admin_finance_screen.dart';
import 'manage_users_screen.dart';
import 'admin_approvals.dart';

// ─── Widgetlar ────────────────────────────────────────────
import '../widgets/balance_card.dart';
import '../widgets/home_header.dart';
import '../widgets/home_grid_action.dart';
import '../widgets/pwa_prompt.dart';

// ═══════════════════════════════════════════════════════════
// KONSTANTALAR
// ═══════════════════════════════════════════════════════════

class AppRoles {
  static const admin     = 'admin';
  static const worker    = 'worker';
  static const installer = 'installer';
}

class OrderStatus {
  static const pending   = 'pending';
  static const completed = 'completed';
  static const canceled  = 'canceled';
}

// ═══════════════════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;

  bool   _isLoading = true;
  int    _bottomIdx = 0;

  // ─── Profil ───────────────────────────────────────────────
  String _userRole     = AppRoles.worker;
  String _userName     = '';
  String _positionName = '';
  double _baseSalary   = 0;
  double _bonusPct     = 0;

  // ─── Admin statistikasi ───────────────────────────────────
  int    _clientCount      = 0;
  int    _activeOrders     = 0;
  double _todayRevenue     = 0;
  double _totalRevenue     = 0;
  double _totalExpense     = 0;
  int    _pendingApprovals = 0;
  int    _activeWorkers    = 0;

  // ─── Worker statistikasi ──────────────────────────────────
  double _workerEarned    = 0;
  double _workerWithdrawn = 0;
  double _workerBonus     = 0;
  int    _workerJobCount  = 0; // bajarilgan ishlar soni

  // ─── Oxirgi faoliyatlar ───────────────────────────────────
  List<Map<String, dynamic>> _recentItems = [];

  final _fmt = NumberFormat('#,###');
  String _fmtSum(double v) =>
      '${_fmt.format(v).replaceAll(',', ' ')} so\'m';

  // ─── Salom matni (vaqtga qarab) ───────────────────────────
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 6)  return 'Xayrli tun 🌙';
    if (h < 12) return 'Xayrli tong ☀️';
    if (h < 17) return 'Xayrli kun 🌤';
    if (h < 21) return 'Xayrli kech 🌆';
    return 'Xayrli tun 🌙';
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) checkAndShowPwaPrompt(context);
    });
  }

  // ═══════════════════════════════════════════════════════════
  // MA'LUMOT YUKLASH
  // ═══════════════════════════════════════════════════════════

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // ✅ Profil + app_roles JOIN
      final profile = await _supabase
          .from('profiles')
          .select('*, app_roles(name, base_salary, rate_per_unit, role_type)')
          .eq('id', user.id)
          .single();

      _userRole = profile['role'] ?? AppRoles.worker;
      _userName = profile['full_name'] ?? 'Foydalanuvchi';

      final roleInfo = profile['app_roles'] as Map<String, dynamic>?;
      _positionName = roleInfo?['name'] ?? '';
      _baseSalary = (profile['custom_salary'] ?? roleInfo?['base_salary'] ?? 0).toDouble();
      _bonusPct   = (profile['bonus_percentage'] ?? 0).toDouble();

      // ─── ADMIN ──────────────────────────────────────────
      if (_userRole == AppRoles.admin) {
        await _loadAdminData();
      } else {
        // ─── WORKER / boshqa ────────────────────────────
        await _loadWorkerData(user.id);
      }
    } catch (e) {
      debugPrint("HomeScreen xato: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadAdminData() async {
    final today      = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day).toIso8601String();
    final monthStart = DateTime(today.year, today.month, 1).toIso8601String();

    final results = await Future.wait([
      _supabase.from('clients').select('id'),
      _supabase
          .from('orders')
          .select('id, status, total_price, created_at, project_name')
          .order('created_at', ascending: false),
      _supabase
          .from('work_logs')
          .select('id')
          .eq('is_approved', false),
      _supabase
          .from('withdrawals')
          .select('amount')
          .eq('status', 'approved'),
      // Faol xodimlar (shu oy ish topshirgan)
      _supabase
          .from('work_logs')
          .select('worker_id')
          .gte('created_at', monthStart),
    ]);

    final clients        = results[0] as List;
    final orders         = results[1] as List;
    final pendingLogs    = results[2] as List;
    final approvedPays   = results[3] as List;
    final monthlyLogs    = results[4] as List;

    double totalRev = 0;
    double todayRev = 0;
    int activeC = 0;

    for (final o in orders) {
      final status    = (o['status'] ?? '').toString();
      final price     = (o['total_price'] ?? 0).toDouble();
      final createdAt = o['created_at']?.toString() ?? '';

      if (status != OrderStatus.completed && status != OrderStatus.canceled) {
        activeC++;
      }
      totalRev += price;
      if (createdAt.compareTo(todayStart) >= 0) todayRev += price;
    }

    double totalExp = 0;
    for (final w in approvedPays) totalExp += (w['amount'] ?? 0).toDouble();

    // Faol ishchilar (unique worker_id)
    final uniqueWorkers = <dynamic>{};
    for (final l in monthlyLogs) {
      if (l['worker_id'] != null) uniqueWorkers.add(l['worker_id']);
    }

    // Oxirgi 5 ta zakaz
    final recent = orders.take(5).map<Map<String, dynamic>>((o) => {
      'title':      o['project_name']?.toString() ?? 'Zakaz #${o['id']}',
      'status':     (o['status'] ?? 'pending').toString(),
      'created_at': o['created_at']?.toString() ?? '',
    }).toList();

    if (mounted) {
      setState(() {
        _clientCount      = clients.length;
        _activeOrders     = activeC;
        _todayRevenue     = todayRev;
        _totalRevenue     = totalRev;
        _totalExpense     = totalExp;
        _pendingApprovals = pendingLogs.length;
        _activeWorkers    = uniqueWorkers.length;
        _recentItems      = recent;
        _isLoading        = false;
      });
    }
  }

  Future<void> _loadWorkerData(String userId) async {
    final results = await Future.wait([
      // Tasdiqlangan ishlar
      _supabase
          .from('work_logs')
          .select('total_sum')
          .eq('worker_id', userId)
          .eq('is_approved', true),
      // Olingan pullar
      _supabase
          .from('withdrawals')
          .select('amount')
          .eq('worker_id', userId)
          .eq('status', 'approved'),
      // Oxirgi 5 ta ish
      _supabase
          .from('work_logs')
          .select('task_type, total_sum, is_approved, created_at, orders(order_number)')
          .eq('worker_id', userId)
          .order('created_at', ascending: false)
          .limit(5),
    ]);

    final works      = results[0] as List;
    final withdraws  = results[1] as List;
    final recentLogs = results[2] as List;

    double worksSum = 0;
    for (final w in works) worksSum += (w['total_sum'] ?? 0).toDouble();

    final bonus  = worksSum * _bonusPct / 100;
    final earned = _baseSalary + worksSum + bonus;

    double paid = 0;
    for (final w in withdraws) paid += (w['amount'] ?? 0).toDouble();

    final recent = recentLogs.map<Map<String, dynamic>>((log) => {
      'title':      '${log['task_type'] ?? 'Ish'} · ${log['orders']?['order_number'] ?? '?'}',
      'status':     (log['is_approved'] ?? false) ? 'completed' : 'pending',
      'created_at': log['created_at']?.toString() ?? '',
      'amount':     (log['total_sum'] ?? 0).toDouble(),
    }).toList();

    if (mounted) {
      setState(() {
        _workerEarned    = earned;
        _workerWithdrawn = paid;
        _workerBonus     = bonus;
        _workerJobCount  = works.length;
        _recentItems     = recent;
        _isLoading       = false;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // DIALOGLAR
  // ═══════════════════════════════════════════════════════════

  void _showWithdrawDialog() {
    final ctrl    = TextEditingController();
    final balance = _workerEarned - _workerWithdrawn;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Avans so'rash",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Mavjud balans: ${_fmtSum(balance)}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Summa",
              border: OutlineInputBorder(),
              suffixText: "so'm",
              prefixIcon: Icon(Icons.monetization_on_outlined),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E5BFF),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final amount = double.tryParse(ctrl.text) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Noto'g'ri summa!")));
                return;
              }
              if (amount > balance) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Balans yetarli emas!"),
                        backgroundColor: Colors.red));
                return;
              }
              try {
                await _supabase.from('withdrawals').insert({
                  'worker_id': _supabase.auth.currentUser!.id,
                  'amount':    amount,
                  'status':    'pending',
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadAll();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("So'rov yuborildi ✅"),
                        backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
              }
            },
            child: const Text("YUBORISH"),
          ),
        ],
      ),
    );
  }

  void _showWorkDialog() async {
    final results = await Future.wait([
      _supabase
          .from('orders')
          .select('id, project_name, order_number, total_area_m2, client_name')
          .not('status', 'in', '("completed","canceled")')
          .order('created_at', ascending: false),
      _supabase.from('task_types').select('id, name, default_rate, target_status'),
    ]);

    if (!mounted) return;

    final orders    = List<Map<String, dynamic>>.from(results[0]);
    final taskTypes = List<Map<String, dynamic>>.from(results[1]);

    dynamic selectedOrderId;
    Map<String, dynamic>? selectedTask;
    final areaCtrl  = TextEditingController();
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final area      = double.tryParse(areaCtrl.text) ?? 0;
          final rate      = (selectedTask?['default_rate'] ?? 0).toDouble();
          final estimated = area * rate;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20, right: 20, top: 20,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Drag handle
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  )),
              const SizedBox(height: 16),

              // Sarlavha
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E5BFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_task, color: Color(0xFF2E5BFF)),
                ),
                const SizedBox(width: 12),
                const Text("Ish Topshirish",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 20),

              // Zakaz
              DropdownButtonFormField<dynamic>(
                decoration: const InputDecoration(
                  labelText: "Zakaz tanlang",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
                isExpanded: true,
                items: orders.map((o) {
                  final client = (o['client_name'] ?? '').toString();
                  final label  = o['project_name'] ?? o['order_number'] ?? '—';
                  return DropdownMenuItem(
                    value: o['id'],
                    child: Text(
                      client.isNotEmpty ? '$label ($client)' : '$label',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) => setM(() {
                  selectedOrderId = v;
                  final full = orders.firstWhere((o) => o['id'] == v, orElse: () => {});
                  if (full['total_area_m2'] != null) {
                    areaCtrl.text = full['total_area_m2'].toString();
                  }
                }),
              ),
              const SizedBox(height: 12),

              // Ish turi
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(
                  labelText: "Ish turi",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.construction_outlined),
                ),
                items: taskTypes.map((t) => DropdownMenuItem(
                  value: t,
                  child: Row(children: [
                    Expanded(child: Text(t['name'] ?? '—')),
                    Text(
                      '${_fmt.format(t['default_rate'] ?? 0)} so\'m',
                      style: TextStyle(color: Colors.green.shade600, fontSize: 12),
                    ),
                  ]),
                )).toList(),
                onChanged: (v) => setM(() => selectedTask = v),
              ),
              const SizedBox(height: 12),

              // Hajm + izoh
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: areaCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setM(() {}),
                    decoration: const InputDecoration(
                      labelText: "Hajm",
                      border: OutlineInputBorder(),
                      suffixText: "m²",
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: "Izoh",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ]),

              // Taxminiy hisob
              if (selectedTask != null && estimated > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calculate_outlined, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "Taxminiy haq: ${_fmtSum(estimated)}",
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 20),

              // Topshirish tugmasi
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E5BFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text("TOPSHIRISH",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    if (selectedOrderId == null || selectedTask == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text("Zakaz va ish turini tanlang!")));
                      return;
                    }
                    if ((double.tryParse(areaCtrl.text) ?? 0) <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text("Hajmni kiriting!")));
                      return;
                    }
                    try {
                      await _supabase.from('work_logs').insert({
                        'worker_id':   _supabase.auth.currentUser!.id,
                        'order_id':    selectedOrderId,
                        'task_type':   selectedTask!['name'],
                        'area_m2':     double.tryParse(areaCtrl.text) ?? 0,
                        'rate':        (selectedTask!['default_rate'] ?? 0).toDouble(),
                        'description': notesCtrl.text,
                      });

                      final ts = selectedTask!['target_status']?.toString() ?? '';
                      if (ts.isNotEmpty) {
                        await _supabase
                            .from('orders')
                            .update({'status': ts})
                            .eq('id', selectedOrderId);
                      }

                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadAll();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Ish topshirildi ✅"),
                              backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text("Xato: $e"),
                              backgroundColor: Colors.red));
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
            ]),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(children: [
          // ─── Header (HomeHeader widget) ──────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: HomeHeader(
              greeting: _greeting,
              userName: _userName,
            ),
          ),

          // ─── Asosiy kontent ──────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2E5BFF)))
                : RefreshIndicator(
                    onRefresh: _loadAll,
                    color: const Color(0xFF2E5BFF),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      child: _userRole == AppRoles.admin
                          ? _buildAdminBody()
                          : _buildWorkerBody(),
                    ),
                  ),
          ),
        ]),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _userRole != AppRoles.admin
          ? FloatingActionButton.extended(
              onPressed: _showWorkDialog,
              backgroundColor: const Color(0xFF2E5BFF),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_task),
              label: const Text("Ish topshirish"),
              elevation: 4,
            )
          : null,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ADMIN BODY
  // ═══════════════════════════════════════════════════════════

  Widget _buildAdminBody() {
    final netProfit = _totalRevenue - _totalExpense;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ─── BalanceCard (flip karta) ───────────────────────
      // role: 'boss' → "KORXONA KASSASI" ko'rinadi
      BalanceCard(
        role: 'boss',
        mainBalance: netProfit,
        income: _totalRevenue,
        expense: _totalExpense,
        secondaryBalance: _totalExpense,  // ishchilarga to'langan
        statsCount: _activeWorkers,       // faol ishchilar
      ),
      const SizedBox(height: 8),
      Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.touch_app, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text("Kartani bosib aylantiring",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ]),
      ),

      const SizedBox(height: 24),

      // ─── 4 ta statistika kartasi ───────────────────────
      _sectionTitle("📊 Umumiy ko'rsatkichlar"),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          _statCard("Mijozlar",        '$_clientCount ta',  Icons.people_alt_rounded,    const Color(0xFF2E5BFF)),
          _statCard("Faol buyurtmalar",'$_activeOrders ta', Icons.shopping_cart_rounded, const Color(0xFFE65100)),
          _statCard("Bugungi savdo",   _fmtSum(_todayRevenue), Icons.today_rounded,      const Color(0xFF2E7D32)),
          _statCard("Kutmoqda",        '$_pendingApprovals ta', Icons.pending_actions,   const Color(0xFF6A1B9A)),
        ],
      ),

      const SizedBox(height: 24),

      // ─── Tezkor akseslar (HomeGridAction) ─────────────
      _sectionTitle("⚡ Tezkor akseslar"),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
        children: [
          HomeGridAction(
            title: "Yangi buyurtma",
            icon: Icons.add_shopping_cart,
            color: const Color(0xFF2E5BFF),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ClientsScreen())),
          ),
          HomeGridAction(
            title: "Moliya",
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFFE65100),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminFinanceScreen())),
          ),
          HomeGridAction(
            title: "Tasdiqlash",
            icon: Icons.task_alt_rounded,
            color: const Color(0xFF2E7D32),
            // ✅ Badge: tasdiqlanmagan ishlar soni
            badgeCount: _pendingApprovals,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminApprovalsScreen())),
          ),
          HomeGridAction(
            title: "Hisobotlar",
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFF6A1B9A),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
          HomeGridAction(
            title: "Mijozlar",
            icon: Icons.people_outline,
            color: const Color(0xFF00838F),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ClientsScreen())),
          ),
          HomeGridAction(
            title: "Xodimlar",
            icon: Icons.manage_accounts,
            color: const Color(0xFFC62828),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
          ),
        ],
      ),

      const SizedBox(height: 24),

      // ─── Oxirgi zakazlar ───────────────────────────────
      _sectionTitle("🕐 Oxirgi buyurtmalar"),
      const SizedBox(height: 10),
      _recentItems.isEmpty
          ? _emptyCard("Hozircha buyurtmalar yo'q")
          : Column(
              children: _recentItems.map((item) => _recentOrderTile(item)).toList()),

      const SizedBox(height: 24),

      // ─── Boshqaruv ro'yxati ────────────────────────────
      _sectionTitle("⚙️ Boshqaruv"),
      const SizedBox(height: 10),
      _listTile(Icons.list_alt_rounded, "Barcha buyurtmalar",
          const Color(0xFF2E5BFF),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const OrdersListScreen()))),
      _listTile(Icons.manage_accounts, "Xodimlarni boshqarish",
          const Color(0xFF2E7D32),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ManageUsersScreen()))),
    ]);
  }

  // ═══════════════════════════════════════════════════════════
  // WORKER BODY
  // ═══════════════════════════════════════════════════════════

  Widget _buildWorkerBody() {
    final balance = _workerEarned - _workerWithdrawn;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ─── BalanceCard (flip karta) ───────────────────────
      // role: 'worker' → "HODIM KARTASI" ko'rinadi
      BalanceCard(
        role: 'worker',
        mainBalance: balance,
        income: _workerEarned,
        expense: _workerWithdrawn,
        secondaryBalance: _workerWithdrawn,   // orqada: kutilayotgan to'lov
        statsCount: _workerJobCount,          // orqada: bajarilgan ishlar soni
      ),
      const SizedBox(height: 8),
      Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.touch_app, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text("Kartani bosib aylantiring",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ]),
      ),

      // Bonus qator (agar bonusPct > 0)
      if (_bonusPct > 0 && _workerBonus > 0) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
            const SizedBox(width: 8),
            Text(
              "Bonus ($_bonusPct%): ${_fmtSum(_workerBonus)}",
              style: TextStyle(
                  color: Colors.amber.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ]),
        ),
      ],

      const SizedBox(height: 14),

      // Avans so'rash tugmasi
      SizedBox(
        width: double.infinity, height: 46,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF2E5BFF), width: 1.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.account_balance_wallet_outlined,
              color: Color(0xFF2E5BFF)),
          label: const Text("Avans so'rash",
              style: TextStyle(
                  color: Color(0xFF2E5BFF), fontWeight: FontWeight.bold)),
          onPressed: _showWithdrawDialog,
        ),
      ),

      const SizedBox(height: 24),

      // ─── Tezkor akseslar (HomeGridAction) ─────────────
      _sectionTitle("⚡ Tezkor akseslar"),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
        children: [
          HomeGridAction(
            title: "Ish topshirish",
            icon: Icons.add_task,
            color: const Color(0xFF2E5BFF),
            onTap: _showWorkDialog,
          ),
          HomeGridAction(
            title: "Buyurtmalar",
            icon: Icons.list_alt_rounded,
            color: const Color(0xFF2E7D32),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const OrdersListScreen())),
          ),
          HomeGridAction(
            title: "Mijozlar",
            icon: Icons.people_outline,
            color: const Color(0xFF00838F),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ClientsScreen())),
          ),
          HomeGridAction(
            title: "Hisobotlar",
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFF6A1B9A),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
        ],
      ),

      const SizedBox(height: 24),

      // ─── Oxirgi ishlarim ───────────────────────────────
      _sectionTitle("🕐 Oxirgi ishlarim"),
      const SizedBox(height: 10),
      _recentItems.isEmpty
          ? _emptyCard("Hozircha ish topshirilmagan")
          : Column(
              children:
                  _recentItems.map((item) => _recentWorkTile(item)).toList()),
    ]);
  }

  // ═══════════════════════════════════════════════════════════
  // YORDAMCHI WIDGETLAR
  // ═══════════════════════════════════════════════════════════

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.28), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Icon(icon, color: Colors.white54, size: 18),
        ]),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _listTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(text,
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color)),
  );

  Widget _emptyCard(String msg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline, color: Colors.grey, size: 18),
      const SizedBox(width: 10),
      Text(msg, style: const TextStyle(color: Colors.grey, fontSize: 13)),
    ]),
  );

  // Admin uchun zakaz tile
  Widget _recentOrderTile(Map<String, dynamic> item) {
    final status = item['status'].toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor(status).withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
              color: _statusColor(status), shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(item['title'].toString(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _statusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_statusLabel(status),
              style: TextStyle(
                  fontSize: 11,
                  color: _statusColor(status),
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // Worker uchun ish tarixi tile
  Widget _recentWorkTile(Map<String, dynamic> item) {
    final isApproved = item['status'] == 'completed';
    final amount     = (item['amount'] ?? 0.0) as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isApproved
                ? Colors.green.shade100
                : Colors.orange.shade100),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor:
              isApproved ? Colors.green.shade50 : Colors.orange.shade50,
          child: Icon(
            isApproved
                ? Icons.check_circle_outline
                : Icons.pending_outlined,
            color: isApproved ? Colors.green : Colors.orange,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(item['title'].toString(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            _fmtSum(amount),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isApproved ? Colors.green : Colors.orange,
                fontSize: 13),
          ),
          Text(
            isApproved ? "✅ Tasdiqlandi" : "⏳ Kutmoqda",
            style: TextStyle(
                fontSize: 10,
                color: isApproved ? Colors.green : Colors.orange),
          ),
        ]),
      ]),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'completed': return 'Bajarildi';
      case 'canceled':  return 'Bekor';
      case 'material':  return 'Kesish';
      case 'assembly':  return 'Yig\'ish';
      case 'delivery':  return 'Yetkazish';
      default:          return 'Jarayonda';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed': return Colors.green;
      case 'canceled':  return Colors.red;
      case 'material':  return Colors.purple;
      case 'assembly':  return Colors.blue;
      case 'delivery':  return Colors.teal;
      default:          return Colors.orange;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BOTTOM NAV
  // ═══════════════════════════════════════════════════════════

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _bottomIdx,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF2E5BFF),
      unselectedItemColor: Colors.grey,
      elevation: 12,
      selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
      onTap: (i) {
        setState(() => _bottomIdx = i);
        switch (i) {
          case 0: _loadAll(); break;
          case 1:
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ClientsScreen()));
            break;
          case 2:
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const OrdersListScreen()));
            break;
          case 3:
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StatsScreen()));
            break;
          case 4:
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()));
            break;
        }
      },
      items: [
        const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded), label: "Asosiy"),
        const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline), label: "Mijozlar"),
        const BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_rounded), label: "Buyurtmalar"),
        const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded), label: "Hisobotlar"),
        const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), label: "Profil"),
      ],
    );
  }
}