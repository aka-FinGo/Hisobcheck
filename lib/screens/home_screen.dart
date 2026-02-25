import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// O'zimiz yozgan widjetlarni chaqiramiz (importlar to'g'rilangan)
import '../widgets/home_header.dart';
import '../widgets/balance_card.dart';
import '../widgets/home_action_grid.dart';

class AppRoles {
  static const boss = 'boss';     // Boshliq roli qo'shildi!
  static const admin = 'admin';
  static const worker = 'worker';
}

class OrderStatus {
  static const pending = 'pending';
  static const completed = 'completed';
  static const canceled = 'canceled';
}

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

  // Asosiy balanslar
  double _displayEarned = 0;
  double _displayWithdrawn = 0;
  
  // Orqa tomon (Flip) uchun qo'shimcha statistikalar
  double _secondaryBalance = 0; 
  int _statsCount = 0;

  // Admin/Boss uchun zakazlar
  int _totalOrders = 0;
  int _activeOrders = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // ─── BAZADAN MA'LUMOT YUKLASH (BOSS HAM QO'SHILDI) ────────────
  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase.from('profiles').select().eq('id', user.id).single();
      _userRole = profile['role'] ?? AppRoles.worker;
      _userName = profile['full_name'] ?? 'Foydalanuvchi';
      
      // BOSS YOKI ADMIN UCHUN MANTIQ
      if (_userRole == AppRoles.admin || _userRole == AppRoles.boss) {
        final orders = await _supabase.from('orders').select('total_price, status');
        final withdrawals = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');
            
        double totalIncome = 0;
        double totalPaid = 0;
        int active = 0;
        
        for (var o in orders) {
          totalIncome += (o['total_price'] ?? 0).toDouble();
          if (o['status'] != OrderStatus.completed && o['status'] != OrderStatus.canceled) {
            active++;
          }
        }
        for (var w in withdrawals) {
          totalPaid += (w['amount'] ?? 0).toDouble();
        }

        // Ishchilar sonini hisoblash (Karta orqasi uchun)
        final workers = await _supabase.from('profiles').select('id').eq('role', AppRoles.worker);
        
        // Ishchilarga jami qarzdorlikni hisoblash: (Jami qabul qilingan ishlar - Jami berilgan pullar)
        final allWorks = await _supabase.from('work_logs').select('total_sum').eq('is_approved', true);
        double totalWorksSum = 0;
        for (var w in allWorks) totalWorksSum += (w['total_sum'] ?? 0).toDouble();
        double debt = totalWorksSum - totalPaid;
        
        if (mounted) {
          setState(() {
            _displayEarned = totalIncome;
            _displayWithdrawn = totalPaid;
            _totalOrders = orders.length;
            _activeOrders = active;
            
            // Karta orqasidagi ma'lumotlar
            _secondaryBalance = debt > 0 ? debt : 0; 
            _statsCount = workers.length; 
            _isLoading = false;
          });
        }
      } 
      // HODIM (WORKER) UCHUN MANTIQ
      else {
        final works = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id).eq('is_approved', true);
        final withdraws = await _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved');
            
        double earned = 0;
        double paid = 0;
        for (var w in works) earned += (w['total_sum'] ?? 0).toDouble();
        for (var w in withdraws) paid += (w['amount'] ?? 0).toDouble();
        
        if (mounted) {
          setState(() {
            _displayEarned = earned;
            _displayWithdrawn = paid;
            
            // Karta orqasidagi ma'lumotlar
            _secondaryBalance = earned - paid; // Hodimga berilishi kerak bo'lgan qoldiq pul
            _statsCount = works.length; // Bajarilgan jami ishlar soni
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Yuklashda xato: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return "Xayrli tong";
    if (h < 17) return "Xayrli kun";
    return "Xayrli kech";
  }

  // ─── AVANS SO'RASH DIALOGI ────────────────────────────────────
  void _showWithdrawDialog() {
    final amountCtrl = TextEditingController();
    final double balance = _displayEarned - _displayWithdrawn;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Avans so'rash", style: Theme.of(context).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Balans: ${NumberFormat("#,###").format(balance).replaceAll(',', ' ')} so'm", 
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Summa", 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor")),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount > 0 && amount <= balance) {
                await _supabase.from('withdrawals').insert({
                  'worker_id': _supabase.auth.currentUser!.id, 
                  'amount': amount, 
                  'status': OrderStatus.pending
                });
                if (mounted) { 
                  Navigator.pop(ctx); 
                  _loadAllData(); // Yuborgandan keyin ma'lumotlarni yangilaymiz
                }
              }
            },
            child: const Text("Yuborish"),
          ),
        ],
      ),
    );
  }

  // ─── ASOSIY UI QISMI ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Boss va Admin bir xil huquqlarga ega
    final bool isManagement = (_userRole == AppRoles.admin || _userRole == AppRoles.boss);

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAllData,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  children: [
                    // 1. Tepa qism (Header)
                    HomeHeader(greeting: _greeting, userName: _userName),
                    const SizedBox(height: 25),
                    
                    // 2. Katta Kassa Kartasi (Flip Card)
                    BalanceCard(
                      role: _userRole, 
                      mainBalance: _displayEarned - _displayWithdrawn,
                      income: _displayEarned,
                      expense: _displayWithdrawn, 
                      secondaryBalance: _secondaryBalance, 
                      statsCount: _statsCount, 
                    ),
                    const SizedBox(height: 25),
                    
                    // 3. Tezkor Tugmalar va Mini Statistika (Grid)
                    HomeActionGrid(
                      isAdmin: isManagement,
                      totalOrders: _totalOrders,
                      activeOrders: _activeOrders,
                      onWithdrawTap: _showWithdrawDialog,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
