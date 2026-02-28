import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_themes.dart';
import '../widgets/glass_card.dart';

class UserTransactionsScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const UserTransactionsScreen({
    super.key, 
    required this.userId, 
    required this.fullName
  });

  @override
  State<UserTransactionsScreen> createState() => _UserTransactionsScreenState();
}

class _UserTransactionsScreenState extends State<UserTransactionsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Ma'lumotlar
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  
  // Filtrlar
  String _selectedType = 'Hammasi'; // Hammasi, Kirim, Chiqim
  DateTimeRange? _dateRange;

  // Totallar
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _currentBalance = 0;

  final _fmt = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Tushumlar (Approved Work Logs)
      final logsRes = await _supabase
          .from('work_logs')
          .select('*, profiles!work_logs_worker_id_fkey(full_name), orders(project_name)')
          .eq('worker_id', widget.userId)
          .order('created_at', ascending: false);

      // 2. Chiqimlar (Approved Withdrawals)
      final withdrawRes = await _supabase
          .from('withdrawals')
          .select('*, profiles(full_name)')
          .eq('worker_id', widget.userId)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> combined = [];

      double income = 0;
      for (var l in logsRes) {
        final amt = (l['total_sum'] ?? 0).toDouble();
        final approved = l['is_approved'] == true;
        if (approved) income += amt;

        final projName = l['orders']?['project_name'] ?? "Noma'lum loyiha";

        combined.add({
          'id': l['id'],
          'date': DateTime.parse(l['created_at']),
          'type': 'kirim',
          'title': projName,
          'subtitle': "${l['task_type']} (${l['area_m2']} x ${_fmt.format(l['rate'] ?? 0)})",
          'desc': l['description'],
          'amount': amt,
          'status': approved ? 'Tasdiqlangan' : 'Kutilmoqda',
          'raw': l
        });
      }

      double expense = 0;
      for (var w in withdrawRes) {
        final amt = (w['amount'] ?? 0).toDouble();
        final approved = w['status'] == 'approved';
        if (approved) expense += amt;

        combined.add({
          'id': w['id'],
          'date': DateTime.parse(w['created_at']),
          'type': 'chiqim',
          'title': 'Avans olindi',
          'subtitle': w['description'] ?? "Izohsiz",
          'desc': w['description'],
          'amount': amt,
          'status': approved ? 'Tasdiqlangan' : (w['status'] == 'rejected' ? 'Rad etildi' : 'Kutilmoqda'),
          'raw': w
        });
      }

      // Sanaga ko'ra sort
      combined.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      if (mounted) {
        setState(() {
          _allTransactions = combined;
          _totalIncome = income;
          _totalExpense = expense;
          _currentBalance = income - expense;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Transactions error: $e");
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = List.from(_allTransactions);

    // Turi bo'yicha
    if (_selectedType == 'Kirim') {
      temp = temp.where((t) => t['type'] == 'kirim').toList();
    } else if (_selectedType == 'Chiqim') {
      temp = temp.where((t) => t['type'] == 'chiqim').toList();
    }

    // Sana bo'yicha
    if (_dateRange != null) {
      temp = temp.where((t) {
        final d = t['date'] as DateTime;
        return d.isAfter(_dateRange!.start) && d.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    setState(() {
      _filteredTransactions = temp;
    });
  }

  String _formatSum(double amount) =>
      '${_fmt.format(amount).replaceAll(',', ' ')} so\'m';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statsTheme = theme.extension<StatsTheme>()!;
    final isGlass = theme.scaffoldBackgroundColor == Colors.transparent;

    return Scaffold(
      backgroundColor: isGlass ? Colors.transparent : const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Amallar Tarixi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(widget.fullName, style: TextStyle(fontSize: 12, color: statsTheme.textSecondary)),
          ],
        ),
        backgroundColor: isGlass ? Colors.transparent : null,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: statsTheme.textSecondary),
            onPressed: _loadTransactions,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : _errorMessage != null 
              ? _buildError() 
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final statsTheme = Theme.of(context).extension<StatsTheme>()!;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 1. Totallar (Sticky-like)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildSummaryCards(),
          ),
        ),

        // 2. Filtrlar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFilters(),
          ),
        ),

        // 3. Ro'yxat
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: _filteredTransactions.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded, size: 64, color: statsTheme.textSecondary.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text("Tranzaksiyalar topilmadi", style: TextStyle(color: statsTheme.textSecondary)),
                      ],
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildTransactionItem(_filteredTransactions[i]),
                    childCount: _filteredTransactions.length,
                  ),
                ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final statsTheme = Theme.of(context).extension<StatsTheme>()!;
    return Column(
      children: [
        // Asosiy Balans
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: statsTheme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: statsTheme.border.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Hozirgi Balans", style: TextStyle(color: statsTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                _formatSum(_currentBalance),
                style: TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.bold,
                  color: _currentBalance < 0 ? statsTheme.expense : statsTheme.income,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _miniStat("Tushum", _formatSum(_totalIncome), statsTheme.income, Icons.arrow_downward_rounded),
            const SizedBox(width: 12),
            _miniStat("Chiqim", _formatSum(_totalExpense), statsTheme.expense, Icons.arrow_upward_rounded),
          ],
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color, IconData icon) {
    final statsTheme = Theme.of(context).extension<StatsTheme>()!;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: statsTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statsTheme.border.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: statsTheme.textSecondary, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final theme = Theme.of(context);
    final statsTheme = theme.extension<StatsTheme>()!;
    return Column(
      children: [
        Row(
          children: [
            _filterChip('Hammasi'),
            const SizedBox(width: 8),
            _filterChip('Kirim'),
            const SizedBox(width: 8),
            _filterChip('Chiqim'),
            const Spacer(),
            IconButton(
              onPressed: _showDatePicker,
              icon: Icon(Icons.date_range_rounded, color: _dateRange != null ? AppColors.primary : statsTheme.textSecondary),
              style: IconButton.styleFrom(
                backgroundColor: _dateRange != null ? AppColors.primary.withOpacity(0.1) : statsTheme.cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        if (_dateRange != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Text(
                  "${DateFormat('dd MMM').format(_dateRange!.start)} - ${DateFormat('dd MMM').format(_dateRange!.end)}",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                IconButton(
                  onPressed: () => setState(() { _dateRange = null; _applyFilters(); }),
                  icon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _filterChip(String label) {
    final selected = _selectedType == label;
    final statsTheme = Theme.of(context).extension<StatsTheme>()!;
    return GestureDetector(
      onTap: () => setState(() { _selectedType = label; _applyFilters(); }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : statsTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : statsTheme.border.withOpacity(0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : statsTheme.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> item) {
    final statsTheme = Theme.of(context).extension<StatsTheme>()!;
    final bool isKirim = item['type'] == 'kirim';
    final DateTime date = item['date'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statsTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statsTheme.border.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // Ikona
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isKirim ? statsTheme.income : statsTheme.expense).withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              isKirim ? Icons.add_rounded : Icons.remove_rounded,
              color: isKirim ? statsTheme.income : statsTheme.expense,
            ),
          ),
          const SizedBox(width: 16),
          // Sarlavha
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  item['subtitle'] ?? "",
                  style: TextStyle(fontSize: 12, color: statsTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM, HH:mm').format(date),
                  style: TextStyle(fontSize: 10, color: statsTheme.textSecondary.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          // Summa va Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${isKirim ? '+' : '-'}${_fmt.format(item['amount'])}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isKirim ? statsTheme.income : statsTheme.expense,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item['status'],
                style: TextStyle(
                  fontSize: 10,
                  color: item['status'] == 'Tasdiqlangan' ? statsTheme.income : (item['status'] == 'Rad etildi' ? statsTheme.expense : statsTheme.pending),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final res = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (res != null) {
      setState(() => _dateRange = res);
      _applyFilters();
    }
  }

  Widget _buildError() {
    final statsTheme = Theme.of(context).extension<StatsTheme>()!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: statsTheme.expense),
          const SizedBox(height: 16),
          Text("Xatolik yuz berdi", style: TextStyle(color: statsTheme.textSecondary, fontWeight: FontWeight.bold)),
          Text(_errorMessage ?? '', style: TextStyle(color: statsTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadTransactions, child: const Text("Qayta urinish")),
        ],
      ),
    );
  }
}
