import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_themes.dart';
import '../widgets/glass_card.dart';
import '../services/groq_service.dart';
import '../services/gemini_service.dart';
import '../services/ai_service.dart';
import '../services/encryption_service.dart';
import 'ai_settings_screen.dart';
import 'admin_finance_screen.dart';
import '../services/report_generator_service.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  int _currentIndex = 0; // Internal Tab Index: 0-Dashboard, 1-Stats, 2-AI, 3-Settings
  bool _isLoading = true;
  bool _isAdmin = false;
  String _currentUserId = '';
  DateTime _selectedMonth = DateTime.now();

  // Data
  List<Map<String, dynamic>> _transactions = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _balance = 0;
  double _usdBalance = 0;
  double _usdRate = 12900; // Mock rate

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser!.id;
    _checkRoleAndLoad();
  }

  Future<void> _checkRoleAndLoad() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _supabase.from('profiles').select('is_super_admin, app_roles(role_type)').eq('id', _currentUserId).single();
      _isAdmin = (profile['is_super_admin'] == true) || (profile['app_roles']?['role_type'] == 'aup');
      await _loadData();
    } catch (e) {
      debugPrint("Finance Init Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    final res = await _supabase.from('personal_transactions')
        .select()
        .eq('user_id', _currentUserId)
        .order('created_at', ascending: false);
    
    _transactions = List<Map<String, dynamic>>.from(res);
    _calculateTotals();
    setState(() {});
  }

  void _calculateTotals() {
    _totalIncome = 0;
    _totalExpense = 0;
    _usdBalance = 0;
    
    // Filter by selected month
    final filtered = _transactions.where((t) {
      final date = DateTime.parse(t['created_at']);
      return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
    }).toList();

    for (var tx in filtered) {
      final amt = (tx['amount'] ?? 0).toDouble();
      final isIncome = tx['type'] == 'income';
      
      if (isIncome) {
        _totalIncome += amt;
      } else {
        _totalExpense += amt;
      }

      // Check for USD in description (e.g., "$50")
      final desc = tx['description']?.toString() ?? '';
      if (desc.contains('\$')) {
        try {
          final usdVal = double.parse(desc.split('\$').last.split(' ').first);
          _usdBalance += (isIncome ? 1 : -1) * usdVal;
        } catch (_) {}
      }
    }
    _balance = _totalIncome - _totalExpense;
  }

  void _showAddTransaction({Map<String, dynamic>? initialData}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTransactionModal(
        onSaved: _loadData,
        usdRate: _usdRate,
        initialData: initialData,
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
      body: Stack(
        children: [
          // Background Gradient for Standalone feel
          if (!isGlass) Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.scaffoldBackgroundColor,
                  theme.scaffoldBackgroundColor.withBlue(theme.scaffoldBackgroundColor.blue + 20),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildHeader(theme, statsTheme),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      _DashboardTab(
                        transactions: _transactions.where((t) {
                          final d = DateTime.parse(t['created_at']);
                          return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
                        }).toList(), 
                        statsTheme: statsTheme, 
                        isGlass: isGlass, 
                        income: _totalIncome, 
                        expense: _totalExpense, 
                        balance: _balance,
                        usdBalance: _usdBalance,
                        onEdit: (tx) => _showAddTransaction(initialData: tx),
                      ),
                      _StatsTab(
                        transactions: _transactions.where((t) {
                          final d = DateTime.parse(t['created_at']);
                          return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
                        }).toList(), 
                        statsTheme: statsTheme, 
                        isGlass: isGlass,
                         selectedMonth: _selectedMonth,
                      ),
                      _AiTab(statsTheme: statsTheme, isGlass: isGlass, onRefresh: _loadData),
                      _SettingsTab(isAdmin: _isAdmin, statsTheme: statsTheme, isGlass: isGlass, onRefresh: _loadData),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(theme, statsTheme, isGlass),
    );
  }

  Widget _buildHeader(ThemeData theme, StatsTheme statsTheme) {
    String title = "DASHBOARD";
    if (_currentIndex == 1) title = "STATISTIKA";
    if (_currentIndex == 2) title = "AI ANALYST";
    if (_currentIndex == 3) title = "SOZLAMALAR";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1, fontStyle: FontStyle.italic)),
                  Container(height: 3, width: 40, decoration: BoxDecoration(color: statsTheme.income, borderRadius: BorderRadius.circular(2))),
                ],
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, size: 28)),
            ],
          ),
          const SizedBox(height: 15),
          _buildMonthSelector(statsTheme),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(StatsTheme statsTheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(6, (i) {
          final date = DateTime.now().subtract(Duration(days: 30 * i));
          final isSelected = date.year == _selectedMonth.year && date.month == _selectedMonth.month;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(DateFormat('MMMM').format(date).toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : statsTheme.textSecondary)),
              selected: isSelected,
              onSelected: (v) {
                if (v) {
                  setState(() {
                    _selectedMonth = date;
                    _calculateTotals();
                  });
                }
              },
              selectedColor: statsTheme.income,
              backgroundColor: statsTheme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              side: BorderSide.none,
              showCheckmark: false,
            ),
          );
        }).reversed.toList(),
      ),
    );
  }

  Widget _buildBottomNav(ThemeData theme, StatsTheme statsTheme, bool isGlass) {
    return Container(
      height: 90,
      margin: const EdgeInsets.only(bottom: 20, left: 15, right: 15),
      decoration: BoxDecoration(
        color: isGlass ? Colors.white.withOpacity(0.05) : statsTheme.cardColor,
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 25, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.grid_view_rounded, "Asosiy", statsTheme),
          _navItem(1, Icons.bar_chart_rounded, "Stats", statsTheme),
          
          // Center Droplet Button
          GestureDetector(
            onTap: () => _showAddTransaction(),
            child: Container(
              height: 65,
              width: 65,
              decoration: BoxDecoration(
                color: statsTheme.income,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: statsTheme.income.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [statsTheme.income, statsTheme.income.withBlue(statsTheme.income.blue + 30)],
                ),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 35),
            ),
          ),

          _navItem(2, Icons.auto_awesome_rounded, "AI", statsTheme),
          _navItem(3, Icons.person_outline_rounded, "User", statsTheme),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, StatsTheme statsTheme) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? statsTheme.income : statsTheme.textSecondary, size: 26),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? statsTheme.income : statsTheme.textSecondary, fontSize: 10, fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

// ── TAB COMPONENTS ──

class _DashboardTab extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final StatsTheme statsTheme;
  final bool isGlass;
  final double income;
  final double expense;
  final double balance;
  final double usdBalance;
  final Function(Map<String, dynamic>) onEdit;

  const _DashboardTab({
    required this.transactions, 
    required this.statsTheme, 
    required this.isGlass, 
    required this.income, 
    required this.expense, 
    required this.balance,
    required this.usdBalance,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          _buildBalanceCard(fmt),
          const SizedBox(height: 25),
          const Text("HARAKATLAR DINAMIKASI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
          const SizedBox(height: 15),
          _buildAreaChart(),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("SO'NGGI AMALLAR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
              TextButton(onPressed: () {}, child: const Text("HAMMASI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ),
          ...transactions.take(5).map((tx) => _buildTransactionItem(tx, fmt)),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(NumberFormat fmt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: statsTheme.cardColor,
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: statsTheme.income.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("JAMI BALANS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmt.format(balance), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1)),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 5),
                child: Text("UZS", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              ),
              if (usdBalance != 0) ...[
                const Spacer(),
                Text("${usdBalance > 0 ? '+' : ''}${fmt.format(usdBalance)} \$", 
                  style: TextStyle(color: statsTheme.income.withOpacity(0.8), fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              _miniStat("Kirim", fmt.format(income), statsTheme.income, Icons.arrow_downward_rounded),
              const SizedBox(width: 15),
              _miniStat("Chiqim", fmt.format(expense), statsTheme.expense, Icons.arrow_upward_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaChart() {
    final last7Days = List.generate(7, (i) => DateTime.now().subtract(Duration(days: i))).reversed.toList();
    
    List<FlSpot> incomeSpots = [];
    List<FlSpot> expenseSpots = [];

    for (int i = 0; i < last7Days.length; i++) {
      final day = last7Days[i];
      double dayIncome = 0;
      double dayExpense = 0;
      
      for (var tx in transactions) {
        final txDate = DateTime.parse(tx['created_at']);
        if (txDate.year == day.year && txDate.month == day.month && txDate.day == day.day) {
          if (tx['type'] == 'income') dayIncome += (tx['amount'] ?? 0).toDouble();
          else dayExpense += (tx['amount'] ?? 0).toDouble();
        }
      }
      incomeSpots.add(FlSpot(i.toDouble(), dayIncome));
      expenseSpots.add(FlSpot(i.toDouble(), dayExpense));
    }

    return Container(
      height: 200,
      width: double.infinity,
      padding: const EdgeInsets.only(right: 20, top: 20, left: 10, bottom: 10),
      decoration: BoxDecoration(
        color: statsTheme.cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => statsTheme.cardColor.withOpacity(0.8),
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem("${NumberFormat('#,###').format(s.y)} UZS", const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))).toList(),
            ),
          ),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            _lineData(incomeSpots, statsTheme.income),
            _lineData(expenseSpots, statsTheme.expense),
          ],
        ),
      ),
    );
  }

  LineChartBarData _lineData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.2), color.withOpacity(0)],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx, NumberFormat fmt, Function(Map<String, dynamic>) onEdit) {
    final isIncome = tx['type'] == 'income';
    final date = DateTime.parse(tx['created_at']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statsTheme.cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isIncome ? statsTheme.income : statsTheme.expense).withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(isIncome ? Icons.south_west_rounded : Icons.north_east_rounded, color: isIncome ? statsTheme.income : statsTheme.expense, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx['description']?.isEmpty == true ? (isIncome ? "Kirim" : "Chiqim") : tx['description'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 3),
                Text(DateFormat('dd MMM, HH:mm').format(date), style: TextStyle(color: statsTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Text("${isIncome ? '+' : '-'}${fmt.format(tx['amount'])}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isIncome ? statsTheme.income : statsTheme.expense)),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => onEdit(tx),
            icon: Icon(Icons.edit_rounded, size: 16, color: Colors.grey.withOpacity(0.5)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final StatsTheme statsTheme;
  final bool isGlass;
  final DateTime selectedMonth;

  const _StatsTab({required this.transactions, required this.statsTheme, required this.isGlass, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final expenses = transactions.where((t) => t['type'] == 'expense').toList();
    final categories = <String, double>{};
    for (var tx in expenses) {
      final desc = tx['description']?.toString().split(':').first.trim() ?? 'Boshqa';
      categories[desc] = (categories[desc] ?? 0) + (tx['amount'] ?? 0).toDouble();
    }

    final pieData = categories.entries.map((e) {
      return PieChartSectionData(
        value: e.value,
        title: '',
        color: Colors.primaries[categories.keys.toList().indexOf(e.key) % Colors.primaries.length],
        radius: 50,
      );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("XARAJATLAR TAHLILI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
              Row(
                children: [
                  IconButton(
                    tooltip: "Excel yuklash",
                    onPressed: () {
                      final monthName = DateFormat('MMMM').format(selectedMonth);
                      ReportGeneratorService.generateExcel(transactions, "Moliya_Hisoboti_$monthName", ["description", "amount", "type", "created_at"]);
                    }, 
                    icon: Icon(Icons.description_outlined, size: 20, color: statsTheme.income),
                  ),
                  IconButton(
                    tooltip: "PDF yuklash",
                    onPressed: () {
                      final monthName = DateFormat('MMMM').format(selectedMonth);
                      ReportGeneratorService.generatePdf(transactions, "Moliya_Hisoboti_$monthName", ["description", "amount", "type", "created_at"]);
                    }, 
                    icon: Icon(Icons.picture_as_pdf_outlined, size: 20, color: statsTheme.expense),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 250,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statsTheme.cardColor,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          // Could add setstate here for highlighting
                        },
                      ),
                      sections: pieData.isEmpty ? [PieChartSectionData(value: 1, color: Colors.grey.withOpacity(0.2), radius: 50, title: '')] : pieData,
                      centerSpaceRadius: 40,
                      sectionsSpace: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: categories.entries.take(5).map((e) {
                      final color = Colors.primaries[categories.keys.toList().indexOf(e.key) % Colors.primaries.length];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.key, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Text("OYLIK HISOBOT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
          const SizedBox(height: 15),
          // Simple month-over-month bar chart or similar could go here
          ...categories.entries.map((e) => _buildCategoryBar(e.key, e.value, categories.values.reduce((a, b) => a + b))),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(String label, double value, double total) {
    final percent = total > 0 ? value / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text("${NumberFormat('#,###').format(value)} UZS", style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation(statsTheme.expense.withOpacity(0.7)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiTab extends StatefulWidget {
  final StatsTheme statsTheme;
  final bool isGlass;
  final VoidCallback onRefresh;
  const _AiTab({required this.statsTheme, required this.isGlass, required this.onRefresh});

  @override
  State<_AiTab> createState() => _AiTabState();
}

class _AiTabState extends State<_AiTab> {
  final TextEditingController _msgCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  final _supabase = Supabase.instance.client;
  final _aiService = AiService();

  Future<void> _handleSend() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isTyping) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });
    _msgCtrl.clear();

    try {
      final keys = await _aiService.getValidAiKeys();
      final systemPrompt = """Siz moliyaviy yordamchisiz. Foydalanuvchi matnini tahlil qiling va TRANSAKSIYA ma'lumotlarini JSON formatida qaytaring.
Faqat JSON qaytaring, boshqa matn bo'lmasin.
Format: {"amount": number, "type": "income" | "expense", "description": string}
Misol: "Tushlikka 45000 sarfladim" -> {"amount": 45000, "type": "expense", "description": "Tushlik"}
""";

      String? response;
      if (keys['groq']?.isNotEmpty == true) {
        final res = await GroqService.chatWithFallback(
          apiKey: keys['groq']!,
          primaryModel: "llama-3.3-70b-versatile",
          systemPrompt: systemPrompt,
          userText: text,
        );
        response = res.content;
      } else if (keys['gemini']?.isNotEmpty == true) {
        response = await GeminiService.chat(
          apiKey: keys['gemini']!,
          model: "gemini-1.5-flash",
          systemPrompt: systemPrompt,
          userText: text,
        );
      }

      if (response != null) {
        final cleanJson = response.replaceAll(RegExp(r'```json|```'), '').trim();
        final data = jsonDecode(cleanJson);
        
        // Asosiy bazaga qo'shish
        await _supabase.from('personal_transactions').insert({
          'user_id': _supabase.auth.currentUser!.id,
          'amount': data['amount'],
          'type': data['type'],
          'description': data['description'],
        });

        setState(() {
          _messages.add({
            'role': 'assistant', 
            'text': "Tushundim! ${data['description']} uchun ${data['amount']} so'm ${data['type'] == 'income' ? 'kirim' : 'chiqim'} sifatida saqlandi."
          });
        });
        widget.onRefresh();
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'text': "Kechirasiz, xatolik yuz berdi: $e"});
      });
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _messages.length,
            itemBuilder: (ctx, i) {
              final m = _messages[i];
              final isUser = m['role'] == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: isUser ? widget.statsTheme.income : widget.statsTheme.cardColor,
                    borderRadius: BorderRadius.circular(22).copyWith(
                      bottomRight: isUser ? Radius.zero : const Radius.circular(22),
                      bottomLeft: isUser ? const Radius.circular(22) : Radius.zero,
                    ),
                  ),
                  child: Text(m['text'], style: TextStyle(color: isUser ? Colors.white : null, fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
        ),
        if (_isTyping) Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 10),
          child: Row(
            children: [
              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: widget.statsTheme.income)),
              const SizedBox(width: 10),
              Text("AI tahlil qilmoqda...", style: TextStyle(color: widget.statsTheme.textSecondary, fontSize: 10, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Yozing (masalan: Go'shtga 120k)...",
                    filled: true,
                    fillColor: widget.statsTheme.cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                backgroundColor: widget.statsTheme.income,
                radius: 28,
                child: IconButton(onPressed: _handleSend, icon: const Icon(Icons.send_rounded, color: Colors.white)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  final bool isAdmin;
  final StatsTheme statsTheme;
  final bool isGlass;
  final VoidCallback onRefresh;

  const _SettingsTab({required this.isAdmin, required this.statsTheme, required this.isGlass, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SOZLAMALAR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
          const SizedBox(height: 20),
          
          _buildMenuTile(
            context,
            icon: Icons.auto_awesome_rounded,
            title: "AI Sozlamalari",
            subtitle: "API kalitlar va promptlarni boshqarish",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSettingsScreen())),
          ),
          
          const SizedBox(height: 30),
          if (isAdmin) ...[
            const Text("BOSHQARUV (MANAGER)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
            const SizedBox(height: 15),
            _buildMenuTile(
              context,
              icon: Icons.analytics_outlined,
              title: "Moliyaviy Nazorat",
              subtitle: "Xodimlarning ish haqi va to'lovlari",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceScreen())),
            ),
          ],
          
          const SizedBox(height: 40),
          Center(
            child: Text("Hisobcheck Finance v1.2", style: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 10)),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: statsTheme.cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statsTheme.income.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: statsTheme.income),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

// ── ADD TRANSACTION MODAL ──

class _AddTransactionModal extends StatefulWidget {
  final VoidCallback onSaved;
  final double usdRate;
  final Map<String, dynamic>? initialData;
  const _AddTransactionModal({required this.onSaved, required this.usdRate, this.initialData});

  @override
  State<_AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends State<_AddTransactionModal> {
  final _supabase = Supabase.instance.client;
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  String _type = 'expense';
  bool _isUsd = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rateCtrl.text = widget.usdRate.toString();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _type = data['type'] ?? 'expense';
      _amountCtrl.text = (data['amount'] ?? 0).toString();
      _descCtrl.text = data['description'] ?? '';
      _selectedCat = data['category'];
      _selectedSub = data['subcategory'];
      
      // Check if it was USD (simple check for $ in description or if we add a currency field later)
      if (_descCtrl.text.contains('\$')) {
        _isUsd = true;
      }
    }
  }

  // Hierarchical categories (Simplified for now)
  String? _selectedCat;
  String? _selectedSub;
  
  final Map<String, List<String>> _categories = {
    'Oziq-ovqat': ['Bozor', 'Supermarket', 'Restoran'],
    'Transport': ['Benzin', 'Taksi', 'Jamoat'],
    'Maishiy': ['Ijara', 'Kommal', 'Internet'],
    'Ish Haqi': ['Avans', 'Oylik', 'Bonus'],
    'Boshqa': ['Kutilmagan', 'Sovg\'a'],
  };

  Future<void> _submit() async {
    if (_amountCtrl.text.isEmpty) return;
    setState(() => _isSubmitting = true);

    try {
      final amt = double.parse(_amountCtrl.text);
      final rate = double.tryParse(_rateCtrl.text) ?? widget.usdRate;
      final finalAmt = _isUsd ? amt * rate : amt;
      final desc = _isUsd ? "${_descCtrl.text} (\$${_amountCtrl.text})" : _descCtrl.text;

      final data = {
        'user_id': _supabase.auth.currentUser!.id,
        'amount': finalAmt,
        'type': _type,
        'category': _selectedCat,
        'subcategory': _selectedSub,
        'description': desc,
      };

      if (widget.initialData != null) {
        await _supabase.from('personal_transactions').update(data).eq('id', widget.initialData!['id']);
      } else {
        await _supabase.from('personal_transactions').insert(data);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(25, 25, 25, MediaQuery.of(context).viewInsets.bottom + 25),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("YANGI AMAL", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Switch(
                value: _isUsd, 
                onChanged: (v) => setState(() => _isUsd = v),
                activeColor: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _typeBtn('expense', "CHIQIM", Colors.red),
              const SizedBox(width: 10),
              _typeBtn('income', "KIRIM", Colors.green),
            ],
          ),
          const SizedBox(height: 20),
          if (_isUsd) ...[
            TextField(
              controller: _rateCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Dollar kursi (UZS)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_exchange)),
            ),
            const SizedBox(height: 15),
          ],
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: "0.00",
              prefixText: _isUsd ? "\$ " : "UZS ",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.black.withOpacity(0.05),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedCat,
            decoration: const InputDecoration(labelText: "Kategoriya", border: OutlineInputBorder()),
            items: _categories.keys.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() { _selectedCat = v; _selectedSub = null; }),
          ),
          if (_selectedCat != null) ...[
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedSub,
              decoration: const InputDecoration(labelText: "Podkategoriya", border: OutlineInputBorder()),
              items: _categories[_selectedCat]!.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _selectedSub = v),
            ),
          ],
          const SizedBox(height: 15),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: "Izoh", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 30),
          _isSubmitting 
            ? const Center(child: CircularProgressIndicator())
            : SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: _type == 'income' ? Colors.green : Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: const Text("SAQLASH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
        ],
      ),
    );
  }

  Widget _typeBtn(String t, String label, Color color) {
    final active = _type == t;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = t),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.1) : Colors.transparent,
            border: Border.all(color: active ? color : Colors.grey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(child: Text(label, style: TextStyle(color: active ? color : Colors.grey, fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }
}
