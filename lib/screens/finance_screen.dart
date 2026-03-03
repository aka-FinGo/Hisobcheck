import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_themes.dart';
import '../widgets/glass_card.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  
  bool _isLoading = true;
  bool _isAdmin = false;
  String _currentUserId = '';
  
  List<Map<String, dynamic>> _myTransactions = [];
  List<Map<String, dynamic>> _employeeList = [];
  
  // Filtering
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  
  // For Admin view
  String? _selectedEmployeeId;
  String? _selectedEmployeeName;
  List<Map<String, dynamic>> _selectedEmployeeTransactions = [];
  bool _isLoadingEmployeeDetails = false;

  final _fmt = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser!.id;
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _supabase.from('profiles').select('is_super_admin, app_roles(role_type)').eq('id', _currentUserId).single();
      _isAdmin = (profile['is_super_admin'] == true) || (profile['app_roles']?['role_type'] == 'aup');
      
      if (!_isAdmin) {
        _tabController = TabController(length: 1, vsync: this);
      } else {
        final employees = await _supabase.from('profiles').select('id, full_name').order('full_name');
        _employeeList = List<Map<String, dynamic>>.from(employees);
      }

      await _loadMyTransactions();
    } catch (e) {
      debugPrint("Finance Init Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMyTransactions() async {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

    final res = await _supabase.from('personal_transactions')
        .select()
        .eq('user_id', _currentUserId)
        .gte('created_at', start.toIso8601String())
        .lte('created_at', end.toIso8601String())
        .order('created_at', ascending: false);
    
    setState(() {
      _myTransactions = List<Map<String, dynamic>>.from(res);
    });
  }

  Future<void> _loadEmployeeTransactions(String userId) async {
    setState(() => _isLoadingEmployeeDetails = true);
    try {
      final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

      final res = await _supabase.from('personal_transactions')
          .select()
          .eq('user_id', userId)
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .order('created_at', ascending: false);
          
      setState(() {
        _selectedEmployeeTransactions = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint("Load Employee Trans Error: $e");
    } finally {
      setState(() => _isLoadingEmployeeDetails = false);
    }
  }

  void _addTransaction() {
    final amountCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isUsd = false;
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          final statsTheme = theme.extension<StatsTheme>();
          final isGlass = theme.scaffoldBackgroundColor == Colors.transparent;

          return Container(
            decoration: BoxDecoration(
              color: isGlass ? Colors.black.withOpacity(0.8) : theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 25, right: 25, top: 25,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Maosh/Daromad qo'shish", 
                         style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statsTheme?.income ?? theme.primaryColor)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                        decoration: InputDecoration(
                          labelText: isUsd ? "Summa (USD)" : "Summa (UZS)",
                          prefixIcon: Icon(isUsd ? Icons.attach_money : Icons.money_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isUsd ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text("USD"),
                          Switch(
                            value: isUsd, 
                            onChanged: (v) => setModalState(() => isUsd = v),
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isUsd) ...[
                  const SizedBox(height: 15),
                  TextField(
                    controller: rateCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      labelText: "Kurs (1 USD = ? UZS)",
                      hintText: "Masalan: 12850",
                      prefixIcon: const Icon(Icons.trending_up),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ],
                const SizedBox(height: 15),
                TextField(
                  controller: descCtrl,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    labelText: "Izoh",
                    prefixIcon: const Icon(Icons.notes),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setModalState(() => selectedDate = d);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(DateFormat('dd.MM.yyyy').format(selectedDate)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      final rawAmt = double.tryParse(amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
                      if (rawAmt <= 0) return;
                      
                      double finalUzzAmt = rawAmt;
                      String finalDesc = descCtrl.text.trim();
                      
                      if (isUsd) {
                        final rate = double.tryParse(rateCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
                        if (rate <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Valyuta kursini kiriting!")));
                          return;
                        }
                        finalUzzAmt = rawAmt * rate;
                        finalDesc = "$finalDesc (Maosh: ${rawAmt}\$ Kurs: ${rate})".trim();
                      }

                      try {
                        await _supabase.from('personal_transactions').insert({
                          'user_id': _currentUserId,
                          'type': 'salary',
                          'amount': finalUzzAmt,
                          'category': 'Ish haqi',
                          'description': finalDesc,
                          'created_at': DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 12).toIso8601String(),
                        });
                        Navigator.pop(ctx);
                        _loadMyTransactions();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statsTheme?.income ?? theme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text("Saqlash", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statsTheme = theme.extension<StatsTheme>()!;
    final isGlass = theme.scaffoldBackgroundColor == Colors.transparent;

    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: isGlass ? Colors.transparent : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Moliya"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              if (_isAdmin) TabBar(
                controller: _tabController,
                tabs: const [Tab(text: "Mening tarixim"), Tab(text: "Xodimlar")],
              ),
              _buildMonthSelector(theme, statsTheme),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTransaction,
        backgroundColor: statsTheme.income,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isAdmin 
        ? TabBarView(
            controller: _tabController,
            children: [
              _buildTransactionList(_myTransactions, statsTheme, isGlass),
              _buildAdminView(theme, statsTheme, isGlass),
            ],
          )
        : _buildTransactionList(_myTransactions, statsTheme, isGlass),
    );
  }

  Widget _buildMonthSelector(ThemeData theme, StatsTheme statsTheme) {
    final months = [
      "Yanvar", "Fevral", "Mart", "Aprel", "May", "Iyun", 
      "Iyul", "Avgust", "Sentabr", "Oktabr", "Noyabr", "Dekabr"
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: 12,
        itemBuilder: (ctx, i) {
          final monthDate = DateTime(DateTime.now().year, i + 1, 1);
          final isSelected = _selectedMonth.month == monthDate.month;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(months[i]),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedMonth = monthDate;
                  });
                  _loadMyTransactions();
                  if (_selectedEmployeeId != null) _loadEmployeeTransactions(_selectedEmployeeId!);
                }
              },
              selectedColor: statsTheme.income.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? statsTheme.income : theme.textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionList(List<Map<String, dynamic>> items, StatsTheme statsTheme, bool isGlass) {
    double total = 0;
    for (var item in items) total += (item['amount'] ?? 0).toDouble();

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 60, color: statsTheme.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 15),
            Text("Ushbu oy uchun ma'lumot yo'q", style: TextStyle(color: statsTheme.textSecondary)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSummaryCard(total, statsTheme, isGlass),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final item = items[i];
              final date = DateTime.parse(item['created_at']);
              return _buildTransactionItem(item, date, statsTheme, isGlass);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(double total, StatsTheme statsTheme, bool isGlass) {
    Widget content = Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Oy bo'yicha jami", style: TextStyle(color: statsTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 5),
              Text("${_fmt.format(total)} so'm", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          CircleAvatar(
            backgroundColor: statsTheme.income.withOpacity(0.1),
            child: Icon(Icons.summarize, color: statsTheme.income),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: isGlass 
          ? GlassCard(padding: EdgeInsets.zero, child: content)
          : Container(
              decoration: BoxDecoration(
                color: statsTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statsTheme.border.withOpacity(0.1)),
              ),
              child: content,
            ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> item, DateTime date, StatsTheme statsTheme, bool isGlass) {
    Widget content = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: statsTheme.income.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: Icon(Icons.south_west, color: statsTheme.income, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['description']?.isEmpty == true ? "Daromad" : item['description'], 
                     maxLines: 1, overflow: TextOverflow.ellipsis,
                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(DateFormat('dd MMMM, HH:mm').format(date), 
                     style: TextStyle(color: statsTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Text("+${_fmt.format(item['amount'])}", 
               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: statsTheme.income)),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: isGlass 
          ? GlassCard(padding: EdgeInsets.zero, child: content)
          : Container(
              decoration: BoxDecoration(
                color: statsTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: content,
            ),
    );
  }

  Widget _buildAdminView(ThemeData theme, StatsTheme statsTheme, bool isGlass) {
    return Column(
      children: [
        Container(
          height: 80,
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _employeeList.length,
            itemBuilder: (ctx, i) {
              final emp = _employeeList[i];
              final isSelected = _selectedEmployeeId == emp['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ChoiceChip(
                  label: Text(emp['full_name'] ?? "Noma'lum"),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedEmployeeId = emp['id'];
                        _selectedEmployeeName = emp['full_name'];
                      });
                      _loadEmployeeTransactions(emp['id']);
                    }
                  },
                ),
              );
            },
          ),
        ),
        
        Expanded(
          child: _selectedEmployeeId == null 
            ? Center(child: Text("Xodimni tanlang", style: TextStyle(color: statsTheme.textSecondary)))
            : _isLoadingEmployeeDetails 
              ? const Center(child: CircularProgressIndicator())
              : _buildTransactionList(_selectedEmployeeTransactions, statsTheme, isGlass),
        ),
      ],
    );
  }
}
