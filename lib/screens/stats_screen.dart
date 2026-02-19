import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../widgets/finance_stat_card.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage; // ✅ YANGI: xato xabarini saqlash
  int _touchedIndex = -1;

  // Moliya
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _netProfit = 0;

  // Zakazlar
  int _completedOrders = 0;
  int _activeOrders = 0;
  int _canceledOrders = 0;

  // Top Xodimlar
  List<Map<String, dynamic>> _topWorkers = [];

  // ✅ TUZATILDI: DateFormat o'rniga oddiy O'zbek formati — crash yo'q
  String get _currentMonth {
    final now = DateTime.now();
    const months = [
      'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
      'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'
    ];
    return '${months[now.month - 1]}, ${now.year}';
  }

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
      // 1. ZAKAZLAR VA KIRIM
      final orders = await _supabase
          .from('orders')
          .select('status, total_price');

      double income = 0;
      int completed = 0;
      int active = 0;
      int canceled = 0;

      for (var o in orders) {
        // ✅ TUZATILDI: null bo'lsa 0 qaytaradi, crash yo'q
        income += double.tryParse(o['total_price']?.toString() ?? '0') ?? 0.0;
        final status = (o['status'] ?? 'pending').toString();

        if (status == 'completed') {
          completed++;
        } else if (status == 'canceled') {
          canceled++;
        } else {
          active++;
        }
      }

      // 2. XARAJATLAR
      final withdrawals = await _supabase
          .from('withdrawals')
          .select('amount')
          .eq('status', 'approved');

      double expense = 0;
      for (var w in withdrawals) {
        expense += double.tryParse(w['amount']?.toString() ?? '0') ?? 0.0;
      }

      // 3. TOP XODIMLAR
      final workersStats = await _supabase
          .from('work_logs')
          .select('worker_id, total_sum, profiles(full_name)');

      final Map<String, Map<String, dynamic>> workerMap = {};

      for (var log in workersStats) {
        final uid = log['worker_id']?.toString() ?? '';
        if (uid.isEmpty) continue;

        final name = (log['profiles'] != null &&
                log['profiles']['full_name'] != null)
            ? log['profiles']['full_name'].toString()
            : "Noma'lum";

        final sum =
            double.tryParse(log['total_sum']?.toString() ?? '0') ?? 0.0;

        if (workerMap.containsKey(uid)) {
          workerMap[uid]!['sum'] = (workerMap[uid]!['sum'] as double) + sum;
        } else {
          workerMap[uid] = {'name': name, 'sum': sum};
        }
      }

      final sortedWorkers = workerMap.values.toList()
        ..sort((a, b) => (b['sum'] as double).compareTo(a['sum'] as double));

      if (mounted) {
        setState(() {
          _totalIncome = income;
          _totalExpense = expense;
          _netProfit = income - expense;
          _completedOrders = completed;
          _activeOrders = active;
          _canceledOrders = canceled;
          _topWorkers = sortedWorkers.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Statistika yuklash xatosi: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString(); // ✅ xatoni saqlaymiz
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text(
          "Hisobotlar",
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF2D3142)),
        actions: [
          IconButton(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      // ✅ TUZATILDI: 3 holat — loading, xato, ma'lumot
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : _buildContent(),
    );
  }

  // ✅ YANGI: Xato ko'rsatuvchi widget
  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text(
              "Ma'lumot yuklanmadi",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: const Text("Qayta urinish"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade900,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ YANGI: Asosiy kontent alohida widget
  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // OY BADGE
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _currentMonth,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // MOLIYA KARTALARI
          Row(
            children: [
              FinanceStatCard(
                title: "Jami Kirim",
                amount: _totalIncome,
                color: const Color(0xFF00C853),
                icon: Icons.arrow_downward,
              ),
              const SizedBox(width: 15),
              FinanceStatCard(
                title: "Xarajatlar",
                amount: _totalExpense,
                color: const Color(0xFFFF3D00),
                icon: Icons.arrow_upward,
                isExpense: true,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // SOF FOYDA
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E5BFF), Color(0xFF1441E6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E5BFF).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  "SOF FOYDA (KASSA)",
                  style: TextStyle(
                    color: Colors.white70,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "${NumberFormat("#,###").format(_netProfit).replaceAll(',', ' ')} so'm",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
          const Text(
            "Zakazlar Statistikasi",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          const SizedBox(height: 15),

          // GRAFIK
          Container(
            height: 320,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: (_activeOrders == 0 &&
                          _completedOrders == 0 &&
                          _canceledOrders == 0)
                      ? const Center(
                          child: Text(
                            "Hozircha zakazlar yo'q",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(
                              touchCallback:
                                  (FlTouchEvent event, pieTouchResponse) {
                                if (!mounted) return;
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      pieTouchResponse == null ||
                                      pieTouchResponse.touchedSection ==
                                          null) {
                                    _touchedIndex = -1;
                                    return;
                                  }
                                  _touchedIndex = pieTouchResponse
                                      .touchedSection!.touchedSectionIndex;
                                });
                              },
                            ),
                            borderData: FlBorderData(show: false),
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: _showingSections(),
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Indicator(color: Colors.blue, text: 'Jarayonda'),
                    _Indicator(color: Color(0xFF00C853), text: 'Bitgan'),
                    _Indicator(color: Color(0xFFFF3D00), text: 'Bekor'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
          const Text(
            "Top Xodimlar (Reyting)",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          const SizedBox(height: 15),

          // TOP XODIMLAR
          _topWorkers.isEmpty
              ? const Center(
                  child: Text(
                    "Hozircha ma'lumot yo'q",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _topWorkers.length,
                  itemBuilder: (ctx, i) {
                    final w = _topWorkers[i];
                    // ✅ Medal ranglari faqat 0,1,2 uchun, qolganlari kulrang
                    final medalColor = i == 0
                        ? const Color(0xFFFFD700)
                        : i == 1
                            ? Colors.grey.shade300
                            : i == 2
                                ? const Color(0xFFCD7F32)
                                : Colors.grey.shade200;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: medalColor,
                            child: Text(
                              "${i + 1}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w['name']?.toString() ?? "Noma'lum",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  "Ish haqi: ${NumberFormat("#,###").format(w['sum']).replaceAll(',', ' ')} so'm",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (i == 0)
                            const Icon(
                              Icons.emoji_events,
                              color: Color(0xFFFFD700),
                            ),
                        ],
                      ),
                    );
                  },
                ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ✅ ASOSIY TUZATISH: throw Error() o'chirildi — oq ekran yo'q!
  List<PieChartSectionData> _showingSections() {
    // Agar barcha qiymatlar 0 bo'lsa — bo'sh ro'yxat
    if (_activeOrders == 0 && _completedOrders == 0 && _canceledOrders == 0) {
      return [];
    }

    final isTouched0 = 0 == _touchedIndex;
    final isTouched1 = 1 == _touchedIndex;
    final isTouched2 = 2 == _touchedIndex;

    final sections = <PieChartSectionData>[];

    // Jarayondagi zakazlar
    if (_activeOrders > 0) {
      sections.add(PieChartSectionData(
        color: Colors.blue,
        value: _activeOrders.toDouble(),
        title: '$_activeOrders',
        radius: isTouched0 ? 60.0 : 50.0,
        titleStyle: TextStyle(
          fontSize: isTouched0 ? 20.0 : 14.0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    // Bitgan zakazlar
    if (_completedOrders > 0) {
      sections.add(PieChartSectionData(
        color: const Color(0xFF00C853),
        value: _completedOrders.toDouble(),
        title: '$_completedOrders',
        radius: isTouched1 ? 60.0 : 50.0,
        titleStyle: TextStyle(
          fontSize: isTouched1 ? 20.0 : 14.0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    // Bekor qilingan zakazlar
    if (_canceledOrders > 0) {
      sections.add(PieChartSectionData(
        color: const Color(0xFFFF3D00),
        value: _canceledOrders.toDouble(),
        title: '$_canceledOrders',
        radius: isTouched2 ? 60.0 : 50.0,
        titleStyle: TextStyle(
          fontSize: isTouched2 ? 20.0 : 14.0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    return sections;
  }
}

class _Indicator extends StatelessWidget {
  final Color color;
  final String text;

  const _Indicator({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
