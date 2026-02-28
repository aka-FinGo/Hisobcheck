import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
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

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: Color(0xFF7B8BB2), letterSpacing: 1),
    ),
  );

  Widget _skeletonBox(double w, double h) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
  );

  Widget _card(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    final isGlass = theme.scaffoldBackgroundColor == Colors.transparent;
    
    if (isGlass) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassCard(padding: const EdgeInsets.all(18), child: child),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: child,
    );
  }

  Widget _skeletonCard(BuildContext context) => _card(context, Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_skeletonBox(120, 14), _skeletonBox(80, 14)]),
    const SizedBox(height: 12),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_skeletonBox(100, 14), _skeletonBox(90, 14)]),
  ]));

  Widget _row(BuildContext context, String label, String value, Color valueColor) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(fontSize: 15, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7))),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor)),
    ],
  );

  // ── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isGlass = Theme.of(context).scaffoldBackgroundColor == Colors.transparent;
    return Scaffold(
      backgroundColor: isGlass ? Colors.transparent : null,
      appBar: AppBar(
        title: const Text('Hisobot va Statistika'),
        actions: [
          IconButton(icon: const Icon(Icons.file_download_rounded), onPressed: _showExportOptions),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats),
        ],
      ),
      body: _errorMessage != null ? _buildError() : _buildBody(context),
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassCard(
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text("Hisobotni yuklab olish", style: TextStyle(fontWeight: FontWeight.bold))),
            ListTile(
              leading: const Icon(Icons.table_view, color: Colors.green),
              title: const Text("Excel (.xlsx) formatida"),
              onTap: () { Navigator.pop(ctx); _exportToExcel(); },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text("PDF formatida"),
              onTap: () { Navigator.pop(ctx); _exportToPDF(); },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
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

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final isGlass = theme.scaffoldBackgroundColor == Colors.transparent;

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
            _chip('Oraliq'),
            const SizedBox(width: 8),
            _chip('Hammasi'),
          ]),
        ),
        
        if (_selectedFilter == 'Oraliq') ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final res = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now());
              if (res != null) {
                setState(() => _customDateRange = res);
                _loadStats();
              }
            },
            child: _card(context, Row(children: [
              const Icon(Icons.date_range, color: Colors.blue),
              const SizedBox(width: 10),
              Text(_customDateRange == null ? "Sana oralig'ini tanlang" : "${DateFormat('dd.MM').format(_customDateRange!.start)} - ${DateFormat('dd.MM').format(_customDateRange!.end)}"),
            ])),
          ),
        ],

        if (_isAdmin) ...[
          const SizedBox(height: 10),
          _card(context, DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedWorkerId,
              isExpanded: true,
              hint: const Text("Xodim bo'yicha filtr"),
              items: [
                const DropdownMenuItem(value: null, child: Text("Barcha xodimlar")),
                ..._workers.map((w) => DropdownMenuItem(value: w['id'], child: Text(w['full_name']))),
              ],
              onChanged: (v) {
                setState(() => _selectedWorkerId = v);
                _loadStats();
              },
            ),
          )),
        ],

        // ── MOLIYA (Faqat Admin/AUP uchun) ──
        if (_isAdmin && _selectedWorkerId == null) ...[
          _sectionTitle('💰  MOLIYA'),
          _isLoading ? _skeletonCard(context) : _card(context, Column(children: [
            _row(context, 'Jami tushum',    _formatSum(_totalIncome),        const Color(0xFF00A86B)),
            const Divider(height: 20),
            _row(context, 'Umumiy xarajat',   _formatSum(_totalExpense),        const Color(0xFFE53935)),
            const Divider(height: 20),
            _row(context, 'Taxminiy foyda',    _formatSum(_totalIncome - _totalExpense),
                (_totalIncome - _totalExpense) >= 0 ? Colors.blue : Colors.red),
          ])),
        ],

        // ── ZAKAZLAR (Admin uchun ko'rinadi) ──
        if (_isAdmin && _selectedWorkerId == null) ...[
          _sectionTitle('📦  ZAKAZLAR'),
          _isLoading ? _skeletonCard(context) : _card(context, Column(children: [
            _row(context, 'Jarayonda', '$_activeOrders ta', const Color(0xFFFF8C00)),
            const Divider(height: 20),
            _row(context, 'Bajarilgan', '$_completedOrders ta', const Color(0xFF00A86B)),
            const Divider(height: 20),
            _row(context, 'Bekor qilingan', '$_canceledOrders ta', const Color(0xFFE53935)),
          ])),
        ],

        // ── TOP XODIMLAR (Faqat Admin uchun) ──
        if (_isAdmin && _selectedWorkerId == null) ...[
          _sectionTitle('🏆  TOP XODIMLAR'),
          if (_isLoading) _skeletonCard(context)
          else if (_topWorkers.isEmpty) _card(context, const Center(child: Text("Ma'lumot yo'q")))
          else ...List.generate(_topWorkers.length, (i) {
            final w = _topWorkers[i];
            return _card(context, Row(children: [
              Text("#${i+1}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(child: Text(w['name'] ?? "Xodim", style: const TextStyle(fontWeight: FontWeight.bold))),
              Text(_formatSum(w['sum'] as double), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ]));
          }),
        ],

        // ── TARIX (Audit Log) ──
        _sectionTitle('📜  AMALLAR TARIXI'),
        if (_isLoading) ...[_skeletonCard(context), _skeletonCard(context)]
        else if (_historyItems.isEmpty) _card(context, const Center(child: Text("Hozircha tarix mavjud emas")))
        else ...List.generate(_historyItems.length, (i) {
          final h = _historyItems[i];
          final color = h['type'] == 'kirim' ? Colors.green : Colors.red;
          return _card(context, ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(h['type'] == 'kirim' ? Icons.add_chart : Icons.money_off, color: color, size: 20),
            ),
            title: Text(h['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text("${h['person']} • ${DateFormat('dd.MM.yyyy').format(h['date'])}", style: const TextStyle(fontSize: 11)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("${h['type'] == 'kirim' ? '+' : '-'}${_formatSum(h['amount'])}", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(h['status'], style: TextStyle(fontSize: 9, color: h['status'] == 'Tasdiqlangan' ? Colors.blue : Colors.orange)),
              ],
            ),
          ));
        }),
      ]),
    );
  }

  // --- EXPORT LOGIKASI (NAMUNA) ---
  Future<void> _exportToExcel() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Excel tayyorlanmoqda...")));
    try {
      var excel = excel_pkg.Excel.createExcel();
      var sheet = excel['Sheet1'];
      sheet.appendRow([excel_pkg.TextCellValue('Sana'), excel_pkg.TextCellValue('Xodim'), excel_pkg.TextCellValue('Turi'), excel_pkg.TextCellValue('Summa'), excel_pkg.TextCellValue('Holati')]);
      
      for (var item in _historyItems) {
        sheet.appendRow([
          excel_pkg.TextCellValue(DateFormat('dd.MM.yyyy').format(item['date'])),
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
        pw.TableHelper.fromTextArray(
          context: context,
          data: [
            ['Sana', 'Xodim', 'Turi', 'Summa', 'Holati'],
            ..._historyItems.map((h) => [
              DateFormat('dd.MM.yyyy').format(h['date']),
              h['person'],
              h['title'],
              _formatSum(h['amount']),
              h['status'],
            ]),
          ],
        ),
      ],
    ));
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'hisobot.pdf');
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
