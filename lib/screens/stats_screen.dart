import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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
      DateTime? startDate;
      final now = DateTime.now();

      if (_selectedFilter == 'Bugun') {
        startDate = DateTime(now.year, now.month, now.day);
      } else if (_selectedFilter == 'Hafta') {
        final d = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(d.year, d.month, d.day);
      } else if (_selectedFilter == 'Shu oy') {
        startDate = DateTime(now.year, now.month, 1);
      }

      final iso = startDate?.toIso8601String();

      // PARALLEL so'rovlar
      var ordersQ = _supabase.from('orders').select('status, total_price');
      var withdrawQ = _supabase.from('withdrawals').select('amount').eq('status', 'approved');
      var logsQ = _supabase.from('work_logs').select(
          'worker_id, total_sum, profiles!work_logs_worker_id_fkey(full_name)');

      if (iso != null) {
        ordersQ    = ordersQ.gte('created_at', iso);
        withdrawQ  = withdrawQ.gte('created_at', iso);
        logsQ      = logsQ.gte('created_at', iso);
      }

      final results = await Future.wait([ordersQ, withdrawQ, logsQ]);

      final orders      = results[0];
      final withdrawals = results[1];
      final logs        = results[2];

      double income = 0;
      int completed = 0, active = 0, canceled = 0;
      for (final o in orders) {
        income += double.tryParse(o['total_price']?.toString() ?? '0') ?? 0;
        final s = (o['status'] ?? 'pending').toString();
        if (s == 'completed')     completed++;
        else if (s == 'canceled') canceled++;
        else                      active++;
      }

      double expense = 0;
      for (final w in withdrawals) {
        expense += double.tryParse(w['amount']?.toString() ?? '0') ?? 0;
      }

      final Map<String, Map<String, dynamic>> workerMap = {};
      for (final log in logs) {
        final uid = log['worker_id']?.toString() ?? '';
        if (uid.isEmpty) continue;
        final name = log['profiles']?['full_name']?.toString() ?? "Noma'lum";
        final sum  = double.tryParse(log['total_sum']?.toString() ?? '0') ?? 0;
        if (workerMap.containsKey(uid)) {
          workerMap[uid]!['sum'] = (workerMap[uid]!['sum'] as double) + sum;
        } else {
          workerMap[uid] = {'name': name, 'sum': sum};
        }
      }

      final sorted = workerMap.values.toList()
        ..sort((a, b) => (b['sum'] as double).compareTo(a['sum'] as double));

      if (mounted) {
        setState(() {
          _totalIncome      = income;
          _totalExpense     = expense;
          _completedOrders  = completed;
          _activeOrders     = active;
          _canceledOrders   = canceled;
          _topWorkers       = sorted.take(5).toList();
          _isLoading        = false;
        });
      }
    } catch (e) {
      debugPrint('Stats error: $e');
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  // ── HELPERS ──────────────────────────────────────────────

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: Color(0xFF7B8BB2), letterSpacing: 1),
    ),
  );

  Widget _card(Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFEEF0F7)),
    ),
    child: child,
  );

  Widget _row(String label, String value, Color valueColor) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 15, color: Color(0xFF4A4E6B))),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor)),
    ],
  );

  Widget _skeletonBox(double w, double h) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: const Color(0xFFEEF0F7),
      borderRadius: BorderRadius.circular(8),
    ),
  );

  Widget _skeletonCard() => _card(Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_skeletonBox(120, 14), _skeletonBox(80, 14)]),
    const SizedBox(height: 12),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_skeletonBox(100, 14), _skeletonBox(90, 14)]),
    const SizedBox(height: 12),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_skeletonBox(110, 14), _skeletonBox(85, 14)]),
  ]));

  // ── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Hisobotlar',
            style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF2D3142)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats),
        ],
      ),
      body: _errorMessage != null ? _buildError() : _buildBody(),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFFB0B8D1)),
        const SizedBox(height: 16),
        const Text("Ma'lumot yuklanmadi",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_errorMessage ?? '', textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF7B8BB2), fontSize: 13)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _loadStats,
          icon: const Icon(Icons.refresh),
          label: const Text('Qayta urinish'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E5BFF), foregroundColor: Colors.white),
        ),
      ]),
    ),
  );

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── FILTRLAR ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip('Bugun'),
            const SizedBox(width: 8),
            _chip('Hafta'),
            const SizedBox(width: 8),
            _chip('Shu oy'),
            const SizedBox(width: 8),
            _chip('Hammasi'),
          ]),
        ),

        // ── MOLIYA ──
        _sectionTitle('💰  MOLIYA'),
        _isLoading ? _skeletonCard() : _card(Column(children: [
          _row('Jami kirim',    _formatSum(_totalIncome),        const Color(0xFF00A86B)),
          const Divider(height: 20),
          _row('Xarajatlar',   _formatSum(_totalExpense),        const Color(0xFFE53935)),
          const Divider(height: 20),
          _row('Sof foyda',    _formatSum(_totalIncome - _totalExpense),
              (_totalIncome - _totalExpense) >= 0
                  ? const Color(0xFF2E5BFF) : const Color(0xFFE53935)),
        ])),

        // ── ZAKAZLAR ──
        _sectionTitle('📦  ZAKAZLAR'),
        _isLoading ? _skeletonCard() : _card(Column(children: [
          _row('Jarayonda',            '$_activeOrders ta',     const Color(0xFFFF8C00)),
          const Divider(height: 20),
          _row('Bajarilgan',           '$_completedOrders ta',  const Color(0xFF00A86B)),
          const Divider(height: 20),
          _row('Bekor qilingan',       '$_canceledOrders ta',   const Color(0xFFE53935)),
          const Divider(height: 20),
          _row('Jami',
              '${_activeOrders + _completedOrders + _canceledOrders} ta',
              const Color(0xFF2D3142)),
        ])),

        // ── TOP XODIMLAR ──
        _sectionTitle('🏆  TOP XODIMLAR'),
        if (_isLoading)
          ...[_skeletonCard(), _skeletonCard()]
        else if (_topWorkers.isEmpty)
          _card(const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text("Ma'lumot yo'q", style: TextStyle(color: Color(0xFFB0B8D1))),
            ),
          ))
        else
          ...List.generate(_topWorkers.length, (i) {
            final w = _topWorkers[i];
            final medals = ['🥇', '🥈', '🥉'];
            final badge  = i < 3 ? medals[i] : '${i + 1}.';
            return _card(Row(children: [
              Text(badge, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(w['name']?.toString() ?? "Noma'lum",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Text(_formatSum(w['sum'] as double),
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF2E5BFF), fontWeight: FontWeight.bold)),
            ]));
          }),
      ]),
    );
  }

  Widget _chip(String label) {
    final ok = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: ok,
      onSelected: (_) => setState(() { _selectedFilter = label; _loadStats(); }),
      selectedColor: const Color(0xFF2E5BFF),
      backgroundColor: Colors.white,
      side: BorderSide(color: ok ? const Color(0xFF2E5BFF) : const Color(0xFFDDE1EF)),
      labelStyle: TextStyle(
        color: ok ? Colors.white : const Color(0xFF4A4E6B),
        fontWeight: ok ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
