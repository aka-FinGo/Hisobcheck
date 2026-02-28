import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../theme/app_themes.dart';
import '../widgets/glass_card.dart';

// Eksport xususiyatlari uchun:
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'Shu oy';
  
  // -- YANGI FILTRLAR --
  bool _isAdmin = false;
  String? _selectedWorkerId;
  DateTimeRange? _customDateRange;
  List<dynamic> _workers = []; 
  List<Map<String, dynamic>> _historyItems = []; // Combined audit log

  // Moliya
  double _totalIncome = 0;
  double _totalExpense = 0;

  // Zakazlar
  int _completedOrders = 0;
  int _activeOrders = 0;
  int _canceledOrders = 0;

  // Top Xodimlar
  List<Map<String, dynamic>> _topWorkers = [];

  final _fmt = NumberFormat('#,###');

  String _formatSum(double amount) =>
      '${_fmt.format(amount).replaceAll(',', ' ')} so\'m';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Rollarni va Adminlikni tekshirish
      final profile = await _supabase.from('profiles').select('*, app_roles(role_type)').eq('id', user.id).single();
      _isAdmin = profile['is_super_admin'] == true || (profile['app_roles'] != null && profile['app_roles']['role_type'] == 'aup');

      // 2. Xodimlarni yuklash (Faqat admin uchun)
      if (_isAdmin && _workers.isEmpty) {
        _workers = await _supabase.from('profiles').select('id, full_name').order('full_name');
      }

      // 3. VAQT FILTRI
      DateTime? startDate;
      DateTime? endDate = DateTime.now();
      final now = DateTime.now();

      if (_selectedFilter == 'Bugun') {
        startDate = DateTime(now.year, now.month, now.day);
      } else if (_selectedFilter == 'Hafta') {
        final d = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(d.year, d.month, d.day);
      } else if (_selectedFilter == 'Shu oy') {
        startDate = DateTime(now.year, now.month, 1);
      } else if (_selectedFilter == 'Oraliq' && _customDateRange != null) {
        startDate = _customDateRange!.start;
        endDate = _customDateRange!.end.add(const Duration(days: 1)); // Kun oxirigacha olish uchun
      }

      final startIso = startDate?.toIso8601String();
      final endIso = endDate.toIso8601String();

      // 4. MA'LUMOTLARNI TORTISH
      // Orders (Admin hammasini ko'radi, lekin ishchiga zakazlarni ko'rsatmaymiz)
      var ordersQ = _supabase.from('orders').select('status, total_price, created_at');
      
      // Xarajatlar (Withdrawals)
      var withdrawQ = _supabase.from('withdrawals').select('amount, created_at, status, profiles(full_name)');
      
      // Daromadlar (Work Logs)
      var logsQ = _supabase.from('work_logs').select('worker_id, total_sum, created_at, is_approved, profiles!work_logs_worker_id_fkey(full_name)');

      // Sanaga qarab filtr
      if (startIso != null) {
        ordersQ = ordersQ.gte('created_at', startIso).lt('created_at', endIso);
        withdrawQ = withdrawQ.gte('created_at', startIso).lt('created_at', endIso);
        logsQ = logsQ.gte('created_at', startIso).lt('created_at', endIso);
      }

      // Xodimga qarab filtr (Agar tanlangan bo'lsa)
      final targetWorkerId = _isAdmin ? _selectedWorkerId : user.id;
      if (targetWorkerId != null) {
        withdrawQ = withdrawQ.eq('worker_id', targetWorkerId);
        logsQ = logsQ.eq('worker_id', targetWorkerId);
      }

      final results = await Future.wait([
        ordersQ, 
        withdrawQ.eq('status', 'approved'), 
        logsQ.eq('is_approved', true),
        withdrawQ, // Hammasini audit log uchun qayta tortamiz
        logsQ,     // Hammasini audit log uchun qayta tortamiz
      ]);

      final orders = results[0];
      final approvedWithdrawals = results[1];
      final approvedLogs = results[2];
      final allWithdrawals = results[3];
      final allLogs = results[4];

      // 5. HISOB-KITOBLAR
      double income = 0;
      int completed = 0, active = 0, canceled = 0;
      for (final o in orders) {
        income += (o['total_price'] ?? 0).toDouble();
        final s = (o['status'] ?? 'pending').toString();
        if (s == 'completed') completed++;
        else if (s == 'canceled') canceled++;
        else active++;
      }

      double expense = 0;
      for (final w in approvedWithdrawals) {
        expense += (w['amount'] ?? 0).toDouble();
      }

      // Top xodimlarni hisoblash
      final Map<String, Map<String, dynamic>> workerMap = {};
      for (final log in approvedLogs) {
        final uid = log['worker_id']?.toString() ?? '';
        final name = log['profiles']?['full_name']?.toString() ?? "Noma'lum";
        final sum = (log['total_sum'] ?? 0).toDouble();
        if (workerMap.containsKey(uid)) {
          workerMap[uid]!['sum'] = (workerMap[uid]!['sum'] as double) + sum;
        } else {
          workerMap[uid] = {'name': name, 'sum': sum};
        }
      }

      final sorted = workerMap.values.toList()
        ..sort((a, b) => (b['sum'] as double).compareTo(a['sum'] as double));

      // 6. TArix (AUDIT LOG) JADVALINI YASASH
      List<Map<String, dynamic>> history = [];
      for (var w in allWithdrawals) {
        history.add({
          'date': DateTime.parse(w['created_at']),
          'type': 'chiqim',
          'title': 'Avans olindi',
          'person': w['profiles']?['full_name'] ?? 'Noma\'lum',
          'amount': (w['amount'] ?? 0).toDouble(),
          'status': w['status'] == 'approved' ? 'Tasdiqlangan' : 'Kutilmoqda',
        });
      }
      for (var l in allLogs) {
        history.add({
          'date': DateTime.parse(l['created_at']),
          'type': 'kirim',
          'title': 'Ish haqi hisoblandi',
          'person': l['profiles']?['full_name'] ?? 'Noma\'lum',
          'amount': (l['total_sum'] ?? 0).toDouble(),
          'status': l['is_approved'] == true ? 'Tasdiqlangan' : 'Kutilmoqda',
        });
      }
      history.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      if (mounted) {
        setState(() {
          _totalIncome = income;
          _totalExpense = expense;
          _completedOrders = completed;
          _activeOrders = active;
          _canceledOrders = canceled;
          _topWorkers = sorted.take(5).toList();
          _historyItems = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Stats error: $e');
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  // ── HELPERS ──────────────────────────────────────────────

  Widget _sectionTitle(String text, IconData icon) {
    final statsTheme = Theme.of(context).extension<StatsTheme>()!;
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: statsTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                color: statsTheme.textSecondary, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _skeletonBox(double w, double h) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: Colors.grey.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
  );

  Widget _card(BuildContext context, {required Widget child, EdgeInsets? padding, Color? color}) {
    final theme = Theme.of(context);
    final statsTheme = theme.extension<StatsTheme>()!;
    final isGlass = theme.scaffoldBackgroundColor == Colors.transparent;
    final cardPadding = padding ?? const EdgeInsets.all(20);
    
    if (isGlass) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GlassCard(padding: cardPadding, child: child),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: cardPadding,
      decoration: BoxDecoration(
        color: color ?? statsTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: child,
    );
  }

  Widget _skeletonCard(BuildContext context) => _card(context, child: Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_skeletonBox(120, 14), _skeletonBox(80, 14)]),
    const SizedBox(height: 12),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_skeletonBox(100, 14), _skeletonBox(90, 14)]),
  ]));

  Widget _moneyBox(String label, String value, Color color, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("+ ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              Icon(icon, color: Colors.white.withOpacity(0.8), size: 14),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );

  Widget _miniStatCard(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    ),
  );

  Widget _chip(String label) {
    final theme = Theme.of(context);
    final statsTheme = theme.extension<StatsTheme>()!;
    final ok = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: ok,
      onSelected: (_) => setState(() { _selectedFilter = label; _loadStats(); }),
      selectedColor: AppColors.primary,
      backgroundColor: statsTheme.cardColor,
      elevation: 0,
      pressElevation: 0,
      shadowColor: Colors.transparent,
      side: BorderSide(color: ok ? AppColors.primary : statsTheme.border),
      labelStyle: TextStyle(
        color: ok ? Colors.white : theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
        fontWeight: ok ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statsTheme = theme.extension<StatsTheme>()!;
    final isGlass = theme.scaffoldBackgroundColor == Colors.transparent;
    return Scaffold(
      backgroundColor: isGlass ? Colors.transparent : const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: const Text('Hisobot va Statistika', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: isGlass ? Colors.transparent : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: AppColors.primary), 
            onPressed: _showExportOptions
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: statsTheme.textSecondary), 
            onPressed: _loadStats
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _errorMessage != null ? _buildError() : _buildBody(context),
    );
  }

  void _showExportOptions() {
    final statsTheme = Theme.of(context).extension<StatsTheme>()!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => GlassCard(
        borderRadius: 30,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text("Hisobotni yuklab olish", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
            _exportOptionTile(
              icon: Icons.table_view_rounded,
              color: statsTheme.income,
              title: "Excel (.xlsx) formatida",
              subtitle: "Barcha buxgalteriya amallari jadvali",
              onTap: () { Navigator.pop(ctx); _exportToExcel(); },
            ),
            const SizedBox(height: 8),
            _exportOptionTile(
              icon: Icons.picture_as_pdf_rounded,
              color: statsTheme.expense,
              title: "PDF formatida",
              subtitle: "Chop etish uchun qulay ko'rinish",
              onTap: () { Navigator.pop(ctx); _exportToPDF(); },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _exportOptionTile({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    final statsTheme = Theme.of(context).extension<StatsTheme>()!;
    return Card(
      elevation: 0,
      color: statsTheme.textSecondary.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: statsTheme.textSecondary)),
        onTap: onTap,
        trailing: Icon(Icons.chevron_right_rounded, color: statsTheme.textSecondary),
      ),
    );
  }

  Widget _buildError() {
    final statsTheme = Theme.of(context).extension<StatsTheme>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, size: 72, color: statsTheme.expense.withOpacity(0.5)),
          const SizedBox(height: 24),
          const Text("Ma'lumot yuklanmadi",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(_errorMessage ?? '', textAlign: TextAlign.center,
              style: TextStyle(color: statsTheme.textSecondary, fontSize: 14, height: 1.4)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Qayta urinish', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final statsTheme = Theme.of(context).extension<StatsTheme>()!;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        
        // ── FILTRLAR BLOKI ──
        _card(
          context,
          padding: const EdgeInsets.all(10),
          child: Column(children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(children: [
                _chip('Bugun'),
                const SizedBox(width: 6),
                _chip('Hafta'),
                const SizedBox(width: 6),
                _chip('Shu oy'),
                const SizedBox(width: 6),
                _chip('Oraliq'),
                const SizedBox(width: 6),
                _chip('Hammasi'),
              ]),
            ),
            
            if (_selectedFilter == 'Oraliq') ...[
              const Divider(height: 20),
              GestureDetector(
                onTap: () async {
                  final res = await showDateRangePicker(
                    context: context, 
                    firstDate: DateTime(2023), 
                    lastDate: DateTime.now(),
                    builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)), child: child!),
                  );
                  if (res != null) {
                    setState(() => _customDateRange = res);
                    _loadStats();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _customDateRange == null ? "Sana oralig'ini tanlang" : "${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM').format(_customDateRange!.end)}",
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
                  ]),
                ),
              ),
            ],

            if (_isAdmin) ...[
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: statsTheme.textSecondary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statsTheme.textSecondary.withOpacity(0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedWorkerId,
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down_rounded, color: statsTheme.textSecondary),
                    dropdownColor: statsTheme.cardColor,
                    hint: Text("Xodim bo'yicha filtr", style: TextStyle(color: statsTheme.textSecondary, fontSize: 14)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("Barcha xodimlar ✨")),
                      ..._workers.map((w) => DropdownMenuItem(value: w['id'], child: Text(w['full_name']))),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedWorkerId = v);
                      _loadStats();
                    },
                  ),
                ),
              ),
            ],
          ]),
        ),

        // ── MOLIYA (Faqat Admin/AUP uchun) ──
        if (_isAdmin && _selectedWorkerId == null) ...[
          _sectionTitle('Moliya', Icons.account_balance_wallet_outlined),
          _isLoading ? _skeletonCard(context) : _buildFinanceCard(),
        ],

        // ── ZAKAZLAR ──
        if (_isAdmin && _selectedWorkerId == null) ...[
          _sectionTitle('Zakazlar', Icons.shopping_bag_outlined),
          _isLoading ? _skeletonCard(context) : _buildOrdersCard(),
        ],

        // ── TOP XODIMLAR ──
        if (_isAdmin && _selectedWorkerId == null) ...[
          _sectionTitle('Top Xodimlar', Icons.emoji_events_outlined),
          if (_isLoading) _skeletonCard(context)
          else if (_topWorkers.isEmpty) _card(context, child: const Center(child: Text("Ma'lumot yo'q")))
          else SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(_topWorkers.length, (i) => _buildTopWorkerItem(_topWorkers[i], i)),
            ),
          ),
        ],

        // ── TARIX (Audit Log) ──
        _sectionTitle('Tarix', Icons.history_rounded),
        if (_isLoading) ...[_skeletonCard(context), _skeletonCard(context)]
        else if (_historyItems.isEmpty) _card(context, child: Center(child: Text("Hozircha tarix mavjud emas", style: TextStyle(color: statsTheme.textSecondary))))
        else ...List.generate(_historyItems.length, (i) => _buildHistoryItem(_historyItems[i])),
        
        const SizedBox(height: 20),
      ]),
    );
  }

  // Moliya kartasi
  Widget _buildFinanceCard() {
    final statsTheme = Theme.of(context).extension<StatsTheme>()!;
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Moliya Balansi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text("Bugungi holat bo'yicha", style: TextStyle(color: statsTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 16),
          Row(
            children: [
              _moneyBox('Total Income', _formatSum(_totalIncome), statsTheme.income, Icons.arrow_upward_rounded),
              const SizedBox(width: 12),
              _moneyBox('Total Expense', _formatSum(_totalExpense), statsTheme.expense, Icons.arrow_downward_rounded),
            ],
          ),
        ],
      ),
    );
  }

  // Zakazlar kartasi
  Widget _buildOrdersCard() {
    final statsTheme = Theme.of(context).extension<StatsTheme>()!;
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Zakazlar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniStatCard('Completed', '$_completedOrders', statsTheme.income),
              const SizedBox(width: 8),
              _miniStatCard('Active', '$_activeOrders', statsTheme.active),
              const SizedBox(width: 8),
              _miniStatCard('Canceled', '$_canceledOrders', statsTheme.expense),
            ],
          ),
        ],
      ),
    );
  }

  // Top Xodim elementi (Horizontal)
  Widget _buildTopWorkerItem(Map<String, dynamic> worker, int index) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12, bottom: 10),
      child: _card(
        context,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              child: Text(worker['name']?[0] ?? 'U', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Text(worker['name'] ?? "Xodim", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(_formatSum(worker['sum'] as double), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  // Tarix elementi (Audit Log)
  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final statsTheme = Theme.of(context).extension<StatsTheme>()!;
    final bool isKirim = item['type'] == 'kirim';
    final bool isApproved = item['status'] == 'Tasdiqlangan';

    return _card(
      context,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Chap tomondagi Kirim/Chiqim yozuvlari
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Kirim", style: TextStyle(color: isKirim ? statsTheme.income : statsTheme.textSecondary.withOpacity(0.3), fontWeight: isKirim ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
              Text("Chiqim", style: TextStyle(color: !isKirim ? statsTheme.expense : statsTheme.textSecondary.withOpacity(0.3), fontWeight: !isKirim ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text("Bugun, 10:30", style: TextStyle(fontSize: 11, color: statsTheme.textSecondary)),
              ],
            ),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${isKirim ? '+' : '-'}${_fmt.format(item['amount'])}", 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
              ),
              const SizedBox(height: 4),
              Text(
                isApproved ? "completed" : "pending", 
                style: TextStyle(fontSize: 11, color: statsTheme.textSecondary)
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- EXPORT LOGIKASI ---
  Future<void> _exportToExcel() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Excel tayyorlanmoqda...")));
    try {
      var excel = excel_pkg.Excel.createExcel();
      var sheet = excel['Sheet1'];
      sheet.appendRow([excel_pkg.TextCellValue('Sana'), excel_pkg.TextCellValue('Xodim'), excel_pkg.TextCellValue('Turi'), excel_pkg.TextCellValue('Summa'), excel_pkg.TextCellValue('Holati')]);
      
      for (var item in _historyItems) {
        sheet.appendRow([
          excel_pkg.TextCellValue(DateFormat('dd.MM.yyyy HH:mm').format(item['date'])),
          excel_pkg.TextCellValue(item['person']),
          excel_pkg.TextCellValue(item['title']),
          excel_pkg.DoubleCellValue(item['amount']),
          excel_pkg.TextCellValue(item['status']),
        ]);
      }

      final dir = await getTemporaryDirectory();
      final path = "${dir.path}/Hisobot_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      final file = File(path);
      await file.writeAsBytes(excel.encode()!);
      await Share.shareXFiles([XFile(path)], text: 'Aristokrat Mebel Hisoboti');
    } catch(e) {
      debugPrint("Excel xato: $e");
    }
  }

  Future<void> _exportToPDF() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDF tayyorlanmoqda...")));
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      build: (context) => [
        pw.Header(level: 0, child: pw.Text("Aristokrat Mebel - Hisobot")),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          context: context,
          data: [
            ['Sana', 'Xodim', 'Turi', 'Summa', 'Holati'],
            ..._historyItems.map((h) => [
              DateFormat('dd.MM.yyyy').format(h['date']),
              h['person'],
              h['title'],
              _fmt.format(h['amount']),
              h['status'],
            ]),
          ],
        ),
      ],
    ));
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'hisobot.pdf');
  }
}
