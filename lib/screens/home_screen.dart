import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui'; // Glass uchun

import 'manage_users_screen.dart';
import 'clients_screen.dart';
import 'stats_screen.dart';
import 'user_profile_screen.dart';
import '../theme/theme_provider.dart';

// ─── CONSTANTLAR ────────────────────────────────────────────
class AppRoles {
  static const admin = 'admin';
  static const worker = 'worker';
  static const installer = 'installer';
}

class OrderStatus {
  static const pending = 'pending';
  static const completed = 'completed';
  static const canceled = 'canceled';
}
// ────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  String _userRole = AppRoles.worker;
  String _userName = '';

  double _displayEarned = 0;
  double _displayWithdrawn = 0;

  int _totalOrders = 0;
  int _activeOrders = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // ─── THEME HELPER ─────────────────────────────────────────
  bool get _isDark {
    final mode = context.read<ThemeProvider>().currentMode;
    return mode == AppThemeMode.dark || mode == AppThemeMode.glass;
  }

  bool get _isGlass =>
      context.read<ThemeProvider>().currentMode == AppThemeMode.glass;

  Color get _textPrimary => _isDark ? Colors.white : const Color(0xFF1A1F36);
  Color get _textSecondary => _isDark ? Colors.white60 : Colors.grey.shade600;
  Color get _cardBg => _isGlass
      ? Colors.white.withOpacity(0.12)
      : _isDark
          ? const Color(0xFF1E1E2E)
          : Colors.white;
  Color get _scaffoldBg => _isDark
      ? const Color(0xFF121212)
      : const Color(0xFFF4F6FC);

  // ─── MA'LUMOT YUKLASH ──────────────────────────────────────
  Future<void> _loadAllData() async {
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
        final orders =
            await _supabase.from('orders').select('total_price, status');
        final withdrawals = await _supabase
            .from('withdrawals')
            .select('amount')
            .eq('status', 'approved');

        double totalIncome = 0;
        double totalPaid = 0;
        for (var o in orders) totalIncome += (o['total_price'] ?? 0).toDouble();
        for (var w in withdrawals) totalPaid += (w['amount'] ?? 0).toDouble();

        if (mounted) {
          setState(() {
            _displayEarned = totalIncome;
            _displayWithdrawn = totalPaid;
            _totalOrders = orders.length;
            _activeOrders = orders
                .where((o) =>
                    o['status'] != OrderStatus.completed &&
                    o['status'] != OrderStatus.canceled)
                .length;
            _isLoading = false;
          });
        }
      } else {
        final works = await _supabase
            .from('work_logs')
            .select('total_sum')
            .eq('worker_id', user.id)
            .eq('is_approved', true);
        final withdraws = await _supabase
            .from('withdrawals')
            .select('amount')
            .eq('worker_id', user.id)
            .eq('status', 'approved');

        double earned = 0;
        double paid = 0;
        for (var w in works) earned += (w['total_sum'] ?? 0).toDouble();
        for (var w in withdraws) paid += (w['amount'] ?? 0).toDouble();

        if (mounted) {
          setState(() {
            _displayEarned = earned;
            _displayWithdrawn = paid;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Yuklashda xato: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── FORMATLAR ─────────────────────────────────────────────
  String _formatMoney(double amount) =>
      "${NumberFormat("#,###").format(amount).replaceAll(',', ' ')} so'm";

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return "Xayrli tong";
    if (h < 17) return "Xayrli kun";
    return "Xayrli kech";
  }

  // ─── DIALOGS ───────────────────────────────────────────────
  void _showWithdrawDialog() {
    final amountCtrl = TextEditingController();
    final double balance = _displayEarned - _displayWithdrawn;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet, color: Colors.green),
            ),
            const SizedBox(width: 12),
            Text("Avans so'rash",
                style: TextStyle(color: _textPrimary, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wallet, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text("Mavjud balans: ",
                      style: TextStyle(color: _textSecondary, fontSize: 13)),
                  Text(_formatMoney(balance),
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: _textPrimary),
              decoration: InputDecoration(
                labelText: "Summa",
                suffixText: "so'm",
                labelStyle: TextStyle(color: _textSecondary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF2E5BFF), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Bekor", style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E5BFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Noto'g'ri summa!"),
                    backgroundColor: Colors.orange));
                return;
              }
              if (amount > balance) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Balans yetarli emas!"),
                    backgroundColor: Colors.red));
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
                  _loadAllData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("So'rov yuborildi!"),
                      backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Xato: $e"),
                      backgroundColor: Colors.red));
                }
              }
            },
            child: const Text("Yuborish"),
          ),
        ],
      ),
    ).whenComplete(() => amountCtrl.dispose());
  }

  void _showWorkDialog() async {
    final ordersResp = await _supabase
        .from('orders')
        .select('*, clients(full_name)')
        .neq('status', OrderStatus.completed)
        .order('created_at', ascending: false);
    final taskTypesResp = await _supabase.from('task_types').select();

    if (!mounted) return;

    final orders = List<Map<String, dynamic>>.from(ordersResp);
    final taskTypes = List<Map<String, dynamic>>.from(taskTypesResp);

    dynamic selectedOrder;
    Map<String, dynamic>? selectedTask;
    final areaCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: BoxDecoration(
            color: _isGlass
                ? Colors.white.withOpacity(0.15)
                : _isDark
                    ? const Color(0xFF1E1E2E)
                    : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: _isGlass
                ? Border.all(color: Colors.white.withOpacity(0.2))
                : null,
          ),
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: _isGlass
                  ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E5BFF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_task,
                                color: Color(0xFF2E5BFF)),
                          ),
                          const SizedBox(width: 12),
                          Text("Ish Topshirish",
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Zakaz tanlash
                      DropdownButtonFormField<dynamic>(
                        dropdownColor: _cardBg,
                        style: TextStyle(color: _textPrimary),
                        decoration: _inputDecoration("Zakaz tanlang",
                            Icons.assignment_outlined),
                        isExpanded: true,
                        items: orders
                            .map((o) => DropdownMenuItem(
                                  value: o['id'],
                                  child: Text(
                                    o['project_name'] ?? 'Nomsiz',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: _textPrimary),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setModal(() {
                            selectedOrder = v;
                            final full =
                                orders.firstWhere((o) => o['id'] == v);
                            areaCtrl.text =
                                (full['total_area_m2'] ?? 0).toString();
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Ish turi
                      DropdownButtonFormField<Map<String, dynamic>>(
                        dropdownColor: _cardBg,
                        style: TextStyle(color: _textPrimary),
                        decoration:
                            _inputDecoration("Ish turi", Icons.work_outline),
                        items: taskTypes
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t['name'],
                                      style: TextStyle(color: _textPrimary)),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setModal(() => selectedTask = v),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: areaCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: _textPrimary),
                        decoration: _inputDecoration("Hajm (m²)",
                            Icons.square_foot).copyWith(suffixText: "m²"),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: notesCtrl,
                        style: TextStyle(color: _textPrimary),
                        decoration: _inputDecoration(
                            "Izoh (ixtiyoriy)", Icons.notes),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E5BFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 4,
                          ),
                          onPressed: () async {
                            if (selectedOrder == null ||
                                selectedTask == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "Barcha maydonlarni to'ldiring!")),
                              );
                              return;
                            }
                            try {
                              await _supabase.from('work_logs').insert({
                                'worker_id':
                                    _supabase.auth.currentUser!.id,
                                'order_id': selectedOrder,
                                'task_type': selectedTask!['name'],
                                'area_m2':
                                    double.tryParse(areaCtrl.text) ?? 0,
                                'rate': selectedTask!['default_rate'],
                                'description': notesCtrl.text,
                              });

                              if (selectedTask!['target_status'] != null &&
                                  selectedTask!['target_status']
                                      .toString()
                                      .isNotEmpty) {
                                await _supabase
                                    .from('orders')
                                    .update({'status': selectedTask!['target_status']}).eq('id', selectedOrder);
                              } else if (_userRole == AppRoles.installer) {
                                await _supabase.from('orders').update(
                                    {'status': OrderStatus.completed}).eq(
                                    'id', selectedOrder);
                              }

                              if (mounted) {
                                Navigator.pop(ctx);
                                _loadAllData();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Ish qabul qilindi!"),
                                      backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Xato: $e")),
                                );
                              }
                            }
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 20),
                              SizedBox(width: 8),
                              Text("TOPSHIRISH",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      areaCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _textSecondary),
      prefixIcon: Icon(icon, color: _textSecondary, size: 20),
      filled: true,
      fillColor: _isDark
          ? Colors.white.withOpacity(0.07)
          : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: _isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF2E5BFF), width: 2),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // ThemeProvider o'zgarishlarini kuzatish
    final themeProvider = context.watch<ThemeProvider>();
    final isGlass = themeProvider.currentMode == AppThemeMode.glass;

    Widget content = _isLoading
        ? Center(
            child: CircularProgressIndicator(
              color: const Color(0xFF2E5BFF),
            ),
          )
        : SafeArea(
            child: Stack(
              children: [
                // ASOSIY KONTENT
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── HEADER ──────────────────────────────
                      _buildHeader(),
                      const SizedBox(height: 24),

                      // ── ADMIN MINI STATS ────────────────────
                      if (_userRole == AppRoles.admin) ...[
                        _buildAdminMiniStats(),
                        const SizedBox(height: 20),
                      ],

                      // ── BALANS CARD ─────────────────────────
                      _buildBalanceCard(),
                      const SizedBox(height: 28),

                      // ── MENYU ───────────────────────────────
                      Text("Bo'limlar",
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _textPrimary)),
                      const SizedBox(height: 14),
                      _buildMenuGrid(),
                    ],
                  ),
                ),

                // ── PASTKI TUGMA ─────────────────────────────
                Positioned(
                  bottom: 16,
                  left: 20,
                  right: 20,
                  child: _buildActionButton(),
                ),
              ],
            ),
          );

    // Glass uchun gradient background
    if (isGlass) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF4A148C), Color(0xFF006064)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: content,
    );
  }

  // ─── HEADER ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_greeting,
                style: TextStyle(color: _textSecondary, fontSize: 13)),
            const SizedBox(height: 2),
            Text(_userName,
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        Row(
          children: [
            // Tema almashtirish tugmasi
            _ThemeSwitchButton(textSecondary: _textSecondary, cardBg: _cardBg),
            const SizedBox(width: 10),
            // Profil avatar
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF2E5BFF).withOpacity(0.5),
                      width: 2),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF2E5BFF).withOpacity(0.15),
                  child: Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : "A",
                    style: const TextStyle(
                        color: Color(0xFF2E5BFF),
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── ADMIN MINI STATS ──────────────────────────────────────
  Widget _buildAdminMiniStats() {
    return Row(
      children: [
        Expanded(
          child: _MiniStatTile(
            title: "Jami zakaz",
            value: "$_totalOrders",
            icon: Icons.assignment_outlined,
            color: const Color(0xFF2E5BFF),
            cardBg: _cardBg,
            textPrimary: _textPrimary,
            textSecondary: _textSecondary,
            isGlass: _isGlass,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniStatTile(
            title: "Jarayonda",
            value: "$_activeOrders",
            icon: Icons.timelapse_outlined,
            color: Colors.orange,
            cardBg: _cardBg,
            textPrimary: _textPrimary,
            textSecondary: _textSecondary,
            isGlass: _isGlass,
          ),
        ),
      ],
    );
  }

  // ─── BALANS CARD ───────────────────────────────────────────
  Widget _buildBalanceCard() {
    final balance = _displayEarned - _displayWithdrawn;
    final isAdmin = _userRole == AppRoles.admin;

    return GestureDetector(
      onTap: isAdmin
          ? () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const StatsScreen()))
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E5BFF), Color(0xFF6C3FE8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E5BFF).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAdmin ? "Jami Kirim" : "Mening Balansom",
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      letterSpacing: 0.5),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAdmin
                            ? Icons.bar_chart_rounded
                            : Icons.account_balance_wallet_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAdmin ? "Hisobot" : "Balans",
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _formatMoney(_displayEarned),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5),
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _BalanceRow(
                    label: isAdmin ? "Xarajatlar" : "Olingan",
                    value: _formatMoney(_displayWithdrawn),
                    icon: Icons.arrow_upward_rounded,
                    color: Colors.redAccent.shade100,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withOpacity(0.2),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _BalanceRow(
                      label: isAdmin ? "Sof Foyda" : "Qoldiq",
                      value: _formatMoney(balance),
                      icon: Icons.savings_outlined,
                      color: Colors.greenAccent.shade100,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── MENYU GRID ─────────────────────────────────────────────
  Widget _buildMenuGrid() {
    final items = <_MenuItem>[
      _MenuItem(
        title: "Mijozlar",
        icon: Icons.people_outline_rounded,
        color: Colors.orange,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ClientsScreen())),
      ),
      if (_userRole == AppRoles.admin) ...[
        _MenuItem(
          title: "Hisobotlar",
          icon: Icons.insert_chart_outlined_rounded,
          color: const Color(0xFF6C3FE8),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const StatsScreen())),
        ),
        _MenuItem(
          title: "Xodimlar",
          icon: Icons.manage_accounts_outlined,
          color: Colors.teal,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
        ),
      ],
      if (_userRole != AppRoles.admin)
        _MenuItem(
          title: "Avans So'rash",
          icon: Icons.account_balance_wallet_outlined,
          color: Colors.green,
          onTap: _showWithdrawDialog,
        ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.15,
      children: items
          .map((item) => _MenuCard(
                item: item,
                cardBg: _cardBg,
                textPrimary: _textPrimary,
                isGlass: _isGlass,
              ))
          .toList(),
    );
  }

  // ─── PASTKI TUGMA ──────────────────────────────────────────
  Widget _buildActionButton() {
    final isWorker = _userRole != AppRoles.admin;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (isWorker
                    ? const Color(0xFF2E5BFF)
                    : const Color(0xFF00C853))
                .withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isWorker ? const Color(0xFF2E5BFF) : const Color(0xFF00C853),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        onPressed: isWorker
            ? _showWorkDialog
            : () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ClientsScreen())),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isWorker ? Icons.add_task_rounded : Icons.person_add_rounded,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              isWorker ? "ISH TOPSHIRISH" : "YANGI MIJOZ QO'SHISH",
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TEMA ALMASHTIRISH TUGMASI ────────────────────────────────
class _ThemeSwitchButton extends StatelessWidget {
  final Color textSecondary;
  final Color cardBg;

  const _ThemeSwitchButton(
      {required this.textSecondary, required this.cardBg});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    final mode = provider.currentMode;

    return GestureDetector(
      onTap: () {
        final next = AppThemeMode
            .values[(mode.index + 1) % AppThemeMode.values.length];
        provider.toggleTheme(next);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Icon(
          mode == AppThemeMode.light
              ? Icons.light_mode_rounded
              : mode == AppThemeMode.dark
                  ? Icons.dark_mode_rounded
                  : Icons.auto_awesome_rounded,
          color: mode == AppThemeMode.light
              ? Colors.amber
              : mode == AppThemeMode.dark
                  ? Colors.blueGrey
                  : Colors.purple.shade200,
          size: 20,
        ),
      ),
    );
  }
}

// ─── YORDAMCHI WIDGET'LAR ─────────────────────────────────────
class _MenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _MenuCard extends StatelessWidget {
  final _MenuItem item;
  final Color cardBg;
  final Color textPrimary;
  final bool isGlass;

  const _MenuCard({
    required this.item,
    required this.cardBg,
    required this.textPrimary,
    required this.isGlass,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: isGlass
              ? ImageFilter.blur(sigmaX: 10, sigmaY: 10)
              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: isGlass
                  ? Border.all(color: Colors.white.withOpacity(0.2))
                  : Border.all(color: Colors.transparent),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 24),
                ),
                Text(
                  item.title,
                  style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final bool isGlass;

  const _MiniStatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.isGlass,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: isGlass
            ? ImageFilter.blur(sigmaX: 10, sigmaY: 10)
            : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: isGlass
                ? Border.all(color: Colors.white.withOpacity(0.2))
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          TextStyle(color: textSecondary, fontSize: 11)),
                  Text(value,
                      style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BalanceRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ],
    );
  }
}
