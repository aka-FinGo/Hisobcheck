import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'clients_screen.dart';
import 'stats_screen.dart';
import 'orders_list_screen.dart';
import 'user_profile_screen.dart';
import 'admin_finance_screen.dart';
import 'manage_users_screen.dart';
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

// ─── Asosiy widget ────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;

  bool   _isLoading  = true;
  int    _bottomIdx  = 0;
  String _userRole   = AppRoles.worker;
  String _userName   = '';

  // Admin stats
  int    _clientCount   = 0;
  int    _activeOrders  = 0;
  double _todayRevenue  = 0;
  int    _pendingApprovals = 0;

  // Worker stats
  double _workerEarned    = 0;
  double _workerWithdrawn = 0;

  // Recent activities
  List<Map<String, dynamic>> _recentItems = [];

  final _fmt = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadAll();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) checkAndShowPwaPrompt(context);
    });
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      _userRole = profile['role'] ?? AppRoles.worker;
      _userName = profile['full_name'] ?? 'Foydalanuvchi';

      if (_userRole == AppRoles.admin) {
        // Parallel so'rovlar
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day).toIso8601String();

        final results = await Future.wait([
          _supabase.from('clients').select('id'),
          _supabase.from('orders').select('status, total_price, created_at, project_name'),
          _supabase.from('withdrawals').select('id').eq('status', 'pending'),
        ]);

        final clients     = results[0];
        final orders      = results[1];
        final pendingW    = results[2];

        double todayRev = 0;
        int activeC = 0;

        for (final o in orders) {
          final status = (o['status'] ?? '').toString();
          if (status != OrderStatus.completed && status != OrderStatus.canceled) activeC++;
          final createdAt = o['created_at']?.toString() ?? '';
          if (createdAt.compareTo(todayStart) >= 0) {
            todayRev += double.tryParse(o['total_price']?.toString() ?? '0') ?? 0;
          }
        }

        // So'nggi 5 ta zakaz
        final recent = (orders as List).reversed
            .take(5)
            .map((o) => {
              'title': o['project_name']?.toString() ?? 'Zakaz',
              'status': (o['status'] ?? 'pending').toString(),
              'created_at': o['created_at']?.toString() ?? '',
            })
            .toList();

        if (mounted) {
          setState(() {
            _clientCount      = clients.length;
            _activeOrders     = activeC;
            _todayRevenue     = todayRev;
            _pendingApprovals = pendingW.length;
            _recentItems      = List<Map<String, dynamic>>.from(recent);
            _isLoading        = false;
          });
        }
      } else {
        // Xodim uchun parallel
        final results = await Future.wait([
          _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id),
          _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved'),
        ]);

        final works    = results[0];
        final withdraws = results[1];

        double earned = 0, paid = 0;
        for (final w in works)    earned += (w['total_sum'] ?? 0).toDouble();
        for (final w in withdraws) paid   += (w['amount'] ?? 0).toDouble();

        if (mounted) {
          setState(() {
            _workerEarned    = earned;
            _workerWithdrawn = paid;
            _isLoading       = false;
          });
        }
      }
    } catch (e) {
      debugPrint("HomeScreen xato: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // ─── Pul so'rash dialogi (xodim) ─────────────────────────
  void _showWithdrawDialog() {
    final ctrl = TextEditingController();
    final balance = _workerEarned - _workerWithdrawn;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Pul so'rash (Avans)"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Mavjud: ${_fmt.format(balance).replaceAll(',', ' ')} so'm",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 15),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Summa", border: OutlineInputBorder(), suffixText: "so'm"),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            onPressed: () async {
              final amount = double.tryParse(ctrl.text) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Noto'g'ri summa!")));
                return;
              }
              if (amount > balance) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Balans yetarli emas!")));
                return;
              }
              try {
                await _supabase.from('withdrawals').insert({
                  'worker_id': _supabase.auth.currentUser!.id,
                  'amount': amount,
                  'status': OrderStatus.pending,
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadAll();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("So'rov yuborildi! ✅"),
                        backgroundColor: Colors.green));
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

  // ─── Ish topshirish dialogi (xodim) ──────────────────────
  void _showWorkDialog() async {
    final ordersResp    = await _supabase.from('orders').select('*, clients(full_name)').neq('status', OrderStatus.completed).order('created_at', ascending: false);
    final taskTypesResp = await _supabase.from('task_types').select();
    if (!mounted) return;

    final orders    = List<Map<String, dynamic>>.from(ordersResp);
    final taskTypes = List<Map<String, dynamic>>.from(taskTypesResp);
    dynamic selectedOrder;
    Map<String, dynamic>? selectedTask;
    final areaCtrl  = TextEditingController();
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setM) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20, right: 20, top: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("Ish Topshirish",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            DropdownButtonFormField(
              decoration: const InputDecoration(labelText: "Zakaz", border: OutlineInputBorder()),
              isExpanded: true,
              items: orders.map((o) => DropdownMenuItem(
                  value: o['id'], child: Text(o['project_name']))).toList(),
              onChanged: (v) => setM(() {
                selectedOrder = v;
                final full = orders.firstWhere((o) => o['id'] == v);
                areaCtrl.text = (full['total_area_m2'] ?? 0).toString();
              }),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<Map<String, dynamic>>(
              decoration: const InputDecoration(labelText: "Ish turi", border: OutlineInputBorder()),
              items: taskTypes.map((t) => DropdownMenuItem(
                  value: t, child: Text(t['name']))).toList(),
              onChanged: (v) => setM(() => selectedTask = v),
            ),
            const SizedBox(height: 10),
            TextField(controller: areaCtrl, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Hajm (m²)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl,
                decoration: const InputDecoration(labelText: "Izoh (ixtiyoriy)", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
                onPressed: () async {
                  if (selectedOrder == null || selectedTask == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Barcha maydonlarni to'ldiring!")));
                    return;
                  }
                  try {
                    await _supabase.from('work_logs').insert({
                      'worker_id': _supabase.auth.currentUser!.id,
                      'order_id':  selectedOrder,
                      'task_type': selectedTask!['name'],
                      'area_m2':   double.tryParse(areaCtrl.text) ?? 0,
                      'rate':      selectedTask!['default_rate'],
                      'description': notesCtrl.text,
                    });
                    if (selectedTask!['target_status'] != null &&
                        selectedTask!['target_status'].toString().isNotEmpty) {
                      await _supabase.from('orders')
                          .update({'status': selectedTask!['target_status']})
                          .eq('id', selectedOrder);
                    } else if (_userRole == AppRoles.installer) {
                      await _supabase.from('orders')
                          .update({'status': OrderStatus.completed})
                          .eq('id', selectedOrder);
                    }
                    if (mounted) {
                      Navigator.pop(context);
                      _loadAll();
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Ish qabul qilindi! ✅"),
                              backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
                  }
                },
                child: const Text("TOPSHIRISH", style: TextStyle(fontSize: 16)),
              ),
            ),
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
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  color: const Color(0xFF1565C0),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: _userRole == AppRoles.admin
                        ? _buildAdminBody()
                        : _buildWorkerBody(),
                  ),
                ),
        ),
      ]),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _userRole != AppRoles.admin
          ? FloatingActionButton.extended(
              onPressed: _showWorkDialog,
              icon: const Icon(Icons.add_task),
              label: const Text("Ish topshirish"),
              backgroundColor: const Color(0xFF1565C0),
            )
          : null,
    );
  }

  // ─── AppBar ───────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(children: [
            // Logo
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Text("ERP DASTURI",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,
                    fontSize: 17, letterSpacing: 1)),
            const Spacer(),
            // Xonish
            IconButton(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
            // Avatar
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const UserProfileScreen())),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.25),
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'A',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── Admin body ───────────────────────────────────────────
  Widget _buildAdminBody() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),

      // Salom
      Text("Assalomu alaykum, $_userName!",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E))),
      const SizedBox(height: 20),

      // 4 ta stat karta (2×2)
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
        children: [
          _statCard("Jami mijozlar",    '$_clientCount',
              Icons.people_alt_rounded,      const Color(0xFF1565C0)),
          _statCard("Buyurtmalar",      '$_activeOrders',
              Icons.shopping_cart_rounded,   const Color(0xFFE65100)),
          _statCard("Bugungi savdo",
              "${_fmt.format(_todayRevenue).replaceAll(',', ' ')} so'm",
              Icons.bar_chart_rounded,       const Color(0xFF2E7D32)),
          _statCard("Kutayotgan",       '$_pendingApprovals',
              Icons.notifications_rounded,   const Color(0xFF6A1B9A)),
        ],
      ),

      const SizedBox(height: 28),

      // Tezkor Akseslar
      _sectionTitle("Tezkor Akseslar"),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          _quickBtn("Yangi Buyurtma",  Icons.add_shopping_cart, const Color(0xFF1565C0),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen()))),
          _quickBtn("Mijozlar",        Icons.people_outline,    const Color(0xFF2E7D32),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen()))),
          _quickBtn("Moliya",          Icons.account_balance_wallet_outlined, const Color(0xFFE65100),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceScreen()))),
          _quickBtn("Hisobotlar",      Icons.bar_chart_rounded, const Color(0xFF6A1B9A),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()))),
        ],
      ),

      const SizedBox(height: 28),

      // Oxirgi faoliyatlar
      _sectionTitle("Oxirgi Faoliyatlar"),
      const SizedBox(height: 10),
      _recentItems.isEmpty
          ? _emptyCard("Hozircha faoliyat yo'q")
          : Column(
              children: _recentItems.map((item) => _recentTile(item)).toList()),

      const SizedBox(height: 28),

      // Boshqa bo'limlar
      _sectionTitle("Boshqaruv"),
      const SizedBox(height: 10),
      _listTile(Icons.manage_accounts, "Xodimlarni boshqarish",  const Color(0xFF1565C0),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen()))),
      _listTile(Icons.receipt_long, "Barcha buyurtmalar", const Color(0xFF2E7D32),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersListScreen()))),
    ]);
  }

  // ─── Worker body ──────────────────────────────────────────
  Widget _buildWorkerBody() {
    final balance = _workerEarned - _workerWithdrawn;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),

      Text("Assalomu alaykum, $_userName!",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E))),
      const SizedBox(height: 20),

      // Balans karta
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(children: [
          const Text("Mening balansim",
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text("${_fmt.format(balance).replaceAll(',', ' ')} so'm",
              style: const TextStyle(color: Colors.white,
                  fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _balanceItem("Ishlab topildi",  _fmt.format(_workerEarned).replaceAll(',', ' ')),
            _balanceItem("Olindi",           _fmt.format(_workerWithdrawn).replaceAll(',', ' ')),
          ]),
        ]),
      ),

      const SizedBox(height: 28),

      // Tezkor akseslar
      _sectionTitle("Tezkor Akseslar"),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          _quickBtn("Ish topshirish", Icons.add_task,                  const Color(0xFF1565C0), _showWorkDialog),
          _quickBtn("Mijozlar",       Icons.people_outline,             const Color(0xFF2E7D32),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen()))),
          _quickBtn("Pul so'rash",    Icons.account_balance_wallet,     const Color(0xFFE65100), _showWithdrawDialog),
          _quickBtn("Hisobotlar",     Icons.bar_chart_rounded,          const Color(0xFF6A1B9A),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()))),
        ],
      ),
    ]);
  }

  // ─── Kichik widgetlar ─────────────────────────────────────

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.75)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Icon(icon, color: Colors.white54, size: 18),
        ]),
        const Spacer(),
        Text(value,
            style: const TextStyle(color: Colors.white,
                fontSize: 20, fontWeight: FontWeight.bold),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _quickBtn(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E8FF)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3142))),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
          color: Color(0xFF1A237E)));

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
      Text(msg, style: const TextStyle(color: Color(0xFF7B8BB2), fontSize: 13)),
      const Spacer(),
      const Icon(Icons.chevron_right, color: Color(0xFFB0B8D1), size: 18),
    ]),
  );

  String _statusLabel(String status) {
    if (status == 'completed') return 'Bajarildi';
    if (status == 'canceled')  return 'Bekor';
    return 'Jarayonda';
  }

  Color _statusColor(String status) {
    if (status == 'completed') return Colors.green;
    if (status == 'canceled')  return Colors.red;
    return Colors.orange;
  }

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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _statusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_statusLabel(status),
              style: TextStyle(fontSize: 11, color: _statusColor(status),
                  fontWeight: FontWeight.bold)),
        ),
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
          Expanded(child: Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
          const Icon(Icons.chevron_right, color: Color(0xFFB0B8D1)),
        ]),
      ),
    );
  }

  Widget _balanceItem(String label, String value) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      const SizedBox(height: 4),
      Text("$value so'm",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ]);
  }

  // ─── Bottom Nav ───────────────────────────────────────────
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _bottomIdx,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF1565C0),
      unselectedItemColor: const Color(0xFF9E9E9E),
      backgroundColor: Colors.white,
      elevation: 12,
      onTap: (i) {
        if (i == 0) {
          setState(() => _bottomIdx = 0);
        } else if (i == 1) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen()));
        } else if (i == 2) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersListScreen()));
        } else if (i == 3) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
        } else if (i == 4) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen()));
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded),    label: "Asosiy"),
        BottomNavigationBarItem(icon: Icon(Icons.people_outline),   label: "Mijozlar"),
        BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: "Buyurtmalar"),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded),label: "Hisobotlar"),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline),   label: "Profil"),
      ],
    );
  }
}
