import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'clients_screen.dart';
import 'stats_screen.dart';
import 'orders_list_screen.dart';
import 'user_profile_screen.dart';
import 'admin_finance_screen.dart';
import 'manage_users_screen.dart';
import 'admin_approvals.dart';
import '../widgets/pwa_prompt.dart';

// ─── Konstantalar ─────────────────────────────────────────
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

// ─── AnimatedCounter widget (balance_card.dart dan ko'chirildi) ───
class AnimatedCounter extends StatelessWidget {
  final double value;
  final TextStyle style;

  const AnimatedCounter({super.key, required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutExpo,
      builder: (context, val, _) {
        final formatted = val
            .toInt()
            .toString()
            .replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]} ',
            );
        return Text("$formatted so'm", style: style);
      },
    );
  }
}

// ─── Asosiy widget ────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;

  bool   _isLoading = true;
  int    _bottomIdx = 0;

  // Profil
  String _userRole     = AppRoles.worker;
  String _userName     = '';
  String _positionName = ''; // app_roles.name
  double _baseSalary   = 0;  // app_roles.base_salary yoki custom_salary
  double _bonusPct     = 0;  // bonus_percentage

  // Admin stats
  int    _clientCount      = 0;
  int    _activeOrders     = 0;
  double _todayRevenue     = 0;
  int    _pendingApprovals = 0;

  // Worker stats
  double _workerEarned    = 0;
  double _workerWithdrawn = 0;
  double _workerBonus     = 0;

  // Oxirgi faoliyatlar
  List<Map<String, dynamic>> _recentItems = [];

  final _fmt = NumberFormat('#,###');

  String _fmtSum(double v) =>
      '${_fmt.format(v).replaceAll(',', ' ')} so\'m';

  @override
  void initState() {
    super.initState();
    _loadAll();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) checkAndShowPwaPrompt(context);
    });
  }

  // ─── MA'LUMOT YUKLASH ────────────────────────────────────
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // ✅ YANGI: position_id → app_roles join
      final profile = await _supabase
          .from('profiles')
          .select('*, app_roles(name, base_salary, rate_per_unit, role_type)')
          .eq('id', user.id)
          .single();

      _userRole = profile['role'] ?? AppRoles.worker;
      _userName = profile['full_name'] ?? 'Foydalanuvchi';

      // ✅ Lavozim nomi
      final roleInfo = profile['app_roles'] as Map<String, dynamic>?;
      _positionName = roleInfo?['name'] ?? '';

      // ✅ custom_salary bo'lsa uni, aks holda app_roles.base_salary
      _baseSalary = (profile['custom_salary'] ?? roleInfo?['base_salary'] ?? 0).toDouble();
      _bonusPct   = (profile['bonus_percentage'] ?? 0).toDouble();

      // ─── ADMIN ────────────────────────────────────────────
      if (_userRole == AppRoles.admin) {
        final today      = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day).toIso8601String();

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
        ]);

        final clients  = results[0] as List;
        final orders   = results[1] as List;
        final pendingW = results[2] as List;

        double todayRev = 0;
        int activeC = 0;

        for (final o in orders) {
          final status = (o['status'] ?? '').toString();
          if (status != OrderStatus.completed && status != OrderStatus.canceled) {
            activeC++;
          }
          final createdAt = o['created_at']?.toString() ?? '';
          if (createdAt.compareTo(todayStart) >= 0) {
            todayRev += (o['total_price'] ?? 0).toDouble();
          }
        }

        // Oxirgi 5 ta zakaz
        final recent = orders.take(5).map<Map<String, dynamic>>((o) => {
          'title': o['project_name']?.toString() ?? 'Zakaz #${o['id']}',
          'status': (o['status'] ?? 'pending').toString(),
          'created_at': o['created_at']?.toString() ?? '',
        }).toList();

        if (mounted) {
          setState(() {
            _clientCount      = clients.length;
            _activeOrders     = activeC;
            _todayRevenue     = todayRev;
            _pendingApprovals = pendingW.length;
            _recentItems      = recent;
            _isLoading        = false;
          });
        }

      // ─── WORKER ───────────────────────────────────────────
      } else {
        final results = await Future.wait([
          // ✅ Faqat TASDIQLANGAN ishlar
          _supabase
              .from('work_logs')
              .select('total_sum')
              .eq('worker_id', user.id)
              .eq('is_approved', true),

          // Olingan pullar
          _supabase
              .from('withdrawals')
              .select('amount')
              .eq('worker_id', user.id)
              .eq('status', 'approved'),

          // Oxirgi ishlar (tarix uchun)
          _supabase
              .from('work_logs')
              .select('task_type, total_sum, is_approved, created_at, orders(order_number)')
              .eq('worker_id', user.id)
              .order('created_at', ascending: false)
              .limit(5),
        ]);

        final works    = results[0] as List;
        final withdraws = results[1] as List;
        final recentLogs = results[2] as List;

        // ✅ Ishlar yig'indisi
        double worksSum = 0;
        for (final w in works) worksSum += (w['total_sum'] ?? 0).toDouble();

        // ✅ Bonus
        final bonus = worksSum * _bonusPct / 100;

        // ✅ Jami: base_salary + ishlar + bonus
        final earned = _baseSalary + worksSum + bonus;

        double paid = 0;
        for (final w in withdraws) paid += (w['amount'] ?? 0).toDouble();

        // Oxirgi ishlar
        final recent = recentLogs.map<Map<String, dynamic>>((log) => {
          'title':      '${log['task_type'] ?? 'Ish'} — ${log['orders']?['order_number'] ?? '?'}',
          'status':     (log['is_approved'] ?? false) ? 'completed' : 'pending',
          'created_at': log['created_at']?.toString() ?? '',
          'amount':     (log['total_sum'] ?? 0).toDouble(),
        }).toList();

        if (mounted) {
          setState(() {
            _workerEarned    = earned;
            _workerWithdrawn = paid;
            _workerBonus     = bonus;
            _recentItems     = recent;
            _isLoading       = false;
          });
        }
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

  // ─── PUL SO'RASH DIALOGI (xodim) ─────────────────────────
  void _showWithdrawDialog() {
    final ctrl    = TextEditingController();
    final balance = _workerEarned - _workerWithdrawn;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Avans so'rash"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // Balans ko'rsatish
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                "Mavjud balans: ${_fmtSum(balance)}",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Summa kiriting",
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
              backgroundColor: const Color(0xFF1565C0),
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
                        content: Text("So'rov yuborildi! ✅"),
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

  // ─── ISH TOPSHIRISH DIALOGI (xodim) ──────────────────────
  void _showWorkDialog() async {
    // Parallel yuklash
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
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Sarlavha
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_task, color: Color(0xFF1565C0)),
              ),
              const SizedBox(width: 12),
              const Text("Ish Topshirish",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 20),

            // Zakaz tanlash
            DropdownButtonFormField<dynamic>(
              decoration: const InputDecoration(
                labelText: "Zakaz",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_cart_outlined),
              ),
              isExpanded: true,
              items: orders.map((o) {
                final label = o['project_name'] ?? o['order_number'] ?? '—';
                final client = o['client_name'] ?? '';
                return DropdownMenuItem(
                  value: o['id'],
                  child: Text(
                    client.isNotEmpty ? '$label ($client)' : label,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) => setM(() {
                selectedOrderId = v;
                // Zakaz tanlanganda maydonni to'ldirish
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
                  Text(t['name'] ?? '—'),
                  const Spacer(),
                  Text(
                    '${_fmt.format(t['default_rate'] ?? 0)} so\'m',
                    style: const TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ]),
              )).toList(),
              onChanged: (v) => setM(() => selectedTask = v),
            ),
            const SizedBox(height: 12),

            // Hajm va izoh — yon yon
            Row(children: [
              Expanded(
                child: TextField(
                  controller: areaCtrl,
                  keyboardType: TextInputType.number,
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
                    labelText: "Izoh (ixtiyoriy)",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ]),

            // Taxminiy summa preview
            if (selectedTask != null && areaCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.calculate_outlined, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Taxminiy: ${_fmtSum(
                      (double.tryParse(areaCtrl.text) ?? 0) *
                      ((selectedTask!['default_rate'] ?? 0).toDouble()),
                    )}",
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send_rounded),
                label: const Text("TOPSHIRISH", style: TextStyle(fontSize: 16)),
                onPressed: () async {
                  if (selectedOrderId == null || selectedTask == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text("Barcha maydonlarni to'ldiring!")));
                    return;
                  }
                  final area = double.tryParse(areaCtrl.text) ?? 0;
                  if (area <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text("Hajmni kiriting!")));
                    return;
                  }
                  try {
                    final rate = (selectedTask!['default_rate'] ?? 0).toDouble();
                    await _supabase.from('work_logs').insert({
                      'worker_id':   _supabase.auth.currentUser!.id,
                      'order_id':    selectedOrderId,
                      'task_type':   selectedTask!['name'],
                      'area_m2':     area,
                      'rate':        rate,
                      'description': notesCtrl.text,
                    });

                    // ✅ target_status bo'lsa zakazni yangilash
                    final targetStatus = selectedTask!['target_status']?.toString() ?? '';
                    if (targetStatus.isNotEmpty) {
                      await _supabase
                          .from('orders')
                          .update({'status': targetStatus})
                          .eq('id', selectedOrderId);
                    }

                    if (mounted) {
                      Navigator.pop(ctx);
                      _loadAll();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Ish topshirildi! ✅"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(children: [
        _buildAppBar(),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1565C0)))
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  color: const Color(0xFF1565C0),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    child: _userRole == AppRoles.admin
                        ? _buildAdminBody()
                        : _buildWorkerBody(),
                  ),
                ),
        ),
      ]),
      bottomNavigationBar: _buildBottomNav(),
      // ✅ Xodim uchun FAB
      floatingActionButton: _userRole != AppRoles.admin
          ? FloatingActionButton.extended(
              onPressed: _showWorkDialog,
              icon: const Icon(Icons.add_task),
              label: const Text("Ish topshirish"),
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              elevation: 4,
            )
          : null,
    );
  }

  // ─── APPBAR ───────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(children: [
            // Logo + nom
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("ERP DASTURI",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1)),
              // ✅ Lavozim nomi ko'rsatiladi
              if (_positionName.isNotEmpty)
                Text(_positionName,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 11)),
            ]),
            const Spacer(),

            // ✅ Admin uchun tasdiqlanmagan ishlar badge
            if (_userRole == AppRoles.admin && _pendingApprovals > 0)
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminApprovalsScreen())),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    const Icon(Icons.notifications_active, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text('$_pendingApprovals',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ]),
                ),
              ),

            // Yangilash
            IconButton(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: "Yangilash",
            ),

            // Avatar → profil
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const UserProfileScreen())),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.25),
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'A',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── ADMIN BODY ───────────────────────────────────────────
  Widget _buildAdminBody() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),

      Text("Assalomu alaykum, $_userName! 👋",
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E))),
      const SizedBox(height: 4),
      Text(
        DateFormat("d MMMM, yyyy — EEEE", "uz").format(DateTime.now()),
        style: const TextStyle(color: Color(0xFF7B8BB2), fontSize: 13),
      ),
      const SizedBox(height: 20),

      // 4 ta stat karta (2×2)
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          _statCard("Jami mijozlar",
              '$_clientCount ta',
              Icons.people_alt_rounded,
              const Color(0xFF1565C0)),
          _statCard("Faol buyurtmalar",
              '$_activeOrders ta',
              Icons.shopping_cart_rounded,
              const Color(0xFFE65100)),
          _statCard("Bugungi savdo",
              _fmtSum(_todayRevenue),
              Icons.bar_chart_rounded,
              const Color(0xFF2E7D32)),
          _statCard("Tasdiq kutmoqda",
              '$_pendingApprovals ta',
              Icons.pending_actions_rounded,
              const Color(0xFF6A1B9A)),
        ],
      ),

      const SizedBox(height: 28),

      // Tezkor akseslar
      _sectionTitle("⚡ Tezkor Akseslar"),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          _quickBtn("Yangi Buyurtma", Icons.add_shopping_cart,
              const Color(0xFF1565C0),
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ClientsScreen()))),
          _quickBtn("Moliya", Icons.account_balance_wallet_outlined,
              const Color(0xFFE65100),
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminFinanceScreen()))),
          _quickBtn("Tasdiqlash", Icons.task_alt_rounded,
              const Color(0xFF2E7D32),
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminApprovalsScreen()))),
          _quickBtn("Hisobotlar", Icons.bar_chart_rounded,
              const Color(0xFF6A1B9A),
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const StatsScreen()))),
        ],
      ),

      const SizedBox(height: 28),

      // Oxirgi zakazlar
      _sectionTitle("🕐 Oxirgi Buyurtmalar"),
      const SizedBox(height: 10),
      _recentItems.isEmpty
          ? _emptyCard("Hozircha faoliyat yo'q")
          : Column(
              children:
                  _recentItems.map((item) => _recentTile(item)).toList()),

      const SizedBox(height: 28),

      // Boshqaruv
      _sectionTitle("⚙️ Boshqaruv"),
      const SizedBox(height: 10),
      _listTile(Icons.manage_accounts, "Xodimlarni boshqarish",
          const Color(0xFF1565C0),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ManageUsersScreen()))),
      _listTile(Icons.receipt_long, "Barcha buyurtmalar",
          const Color(0xFF2E7D32),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const OrdersListScreen()))),
      _listTile(Icons.people_outline, "Mijozlar",
          const Color(0xFFE65100),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ClientsScreen()))),
    ]);
  }

  // ─── WORKER BODY ──────────────────────────────────────────
  Widget _buildWorkerBody() {
    final balance = _workerEarned - _workerWithdrawn;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),

      Text("Assalomu alaykum, $_userName! 👋",
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E))),
      if (_positionName.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(_positionName,
            style: const TextStyle(color: Color(0xFF7B8BB2), fontSize: 13)),
      ],
      const SizedBox(height: 20),

      // ✅ YANGI BALANS KARTI — AnimatedCounter bilan
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(children: [
          const Text("Joriy balansim",
              style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 6),

          // ✅ Animatsiyali raqam
          AnimatedCounter(
            value: balance,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),

          // 3 ta stat
          Row(children: [
            Expanded(child: _balanceCol(
                "Ishlab topildi", _workerEarned, Icons.trending_up, Colors.greenAccent)),
            Container(width: 1, height: 40, color: Colors.white24),
            Expanded(child: _balanceCol(
                "Bonus", _workerBonus, Icons.star_outline, Colors.amberAccent)),
            Container(width: 1, height: 40, color: Colors.white24),
            Expanded(child: _balanceCol(
                "Olindi", _workerWithdrawn, Icons.trending_down, Colors.orangeAccent)),
          ]),

          // ✅ Base salary bo'lsa ko'rsatish
          if (_baseSalary > 0) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.business_center_outlined,
                  color: Colors.white54, size: 14),
              const SizedBox(width: 6),
              Text(
                "Oylik stavka: ${_fmtSum(_baseSalary)}",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ]),
          ],
        ]),
      ),

      const SizedBox(height: 20),

      // Avans so'rash tugmasi
      SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.account_balance_wallet_outlined,
              color: Color(0xFF1565C0)),
          label: const Text("Avans so'rash",
              style: TextStyle(
                  color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
          onPressed: _showWithdrawDialog,
        ),
      ),

      const SizedBox(height: 28),

      // Tezkor akseslar
      _sectionTitle("⚡ Tezkor Akseslar"),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          _quickBtn("Ish topshirish", Icons.add_task,
              const Color(0xFF1565C0), _showWorkDialog),
          _quickBtn("Mijozlar", Icons.people_outline,
              const Color(0xFF2E7D32),
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ClientsScreen()))),
          _quickBtn("Buyurtmalar", Icons.list_alt_rounded,
              const Color(0xFFE65100),
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OrdersListScreen()))),
          _quickBtn("Hisobotlar", Icons.bar_chart_rounded,
              const Color(0xFF6A1B9A),
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const StatsScreen()))),
        ],
      ),

      const SizedBox(height: 28),

      // Oxirgi ishlar
      _sectionTitle("🕐 Oxirgi Ishlarim"),
      const SizedBox(height: 10),
      _recentItems.isEmpty
          ? _emptyCard("Hozircha ish topshirilmagan")
          : Column(
              children:
                  _recentItems.map((item) => _recentWorkTile(item)).toList()),
    ]);
  }

  // ─── KICHIK WIDGETLAR ─────────────────────────────────────

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Icon(icon, color: Colors.white54, size: 18),
        ]),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _quickBtn(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E8FF)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03), blurRadius: 8)
          ],
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3142))),
            ]),
      ),
    );
  }

  Widget _listTile(
      IconData icon, String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E8FF)),
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
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFB0B8D1)),
        ]),
      ),
    );
  }

  // ✅ Worker balans ustunlari
  Widget _balanceCol(
      String label, double val, IconData icon, Color iconColor) {
    return Column(children: [
      Icon(icon, size: 16, color: iconColor),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(color: Colors.white60, fontSize: 10)),
      const SizedBox(height: 2),
      Text(
        '${_fmt.format(val).replaceAll(',', ' ')} so\'m',
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ]);
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(text,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E))),
  );

  Widget _emptyCard(String msg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE0E8FF)),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline, color: Color(0xFFB0B8D1), size: 18),
      const SizedBox(width: 10),
      Text(msg,
          style: const TextStyle(color: Color(0xFF7B8BB2), fontSize: 13)),
    ]),
  );

  // Admin uchun zakaz tile
  Widget _recentTile(Map<String, dynamic> item) {
    final status = item['status'].toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8FF)),
      ),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: _statusColor(status),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(item['title'].toString(),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
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

  // ✅ Worker uchun ish tarixi tile
  Widget _recentWorkTile(Map<String, dynamic> item) {
    final isApproved = item['status'] == 'completed';
    final amount = (item['amount'] ?? 0.0) as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8FF)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: isApproved
              ? Colors.green.shade50
              : Colors.orange.shade50,
          child: Icon(
            isApproved ? Icons.check_circle_outline : Icons.pending_outlined,
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
            isApproved ? "Tasdiqlandi" : "Kutmoqda",
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

  // ─── BOTTOM NAV ───────────────────────────────────────────
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _bottomIdx,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF1565C0),
      unselectedItemColor: const Color(0xFF9E9E9E),
      backgroundColor: Colors.white,
      elevation: 12,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
      onTap: (i) {
        setState(() => _bottomIdx = i);
        switch (i) {
          case 0: break; // Home — hech narsa qilmaymiz
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