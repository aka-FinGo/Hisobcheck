import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// O'zimiz yozgan widjetlarni chaqiramiz
import '../widgets/home_header.dart';
import '../widgets/balance_card.dart';
import '../widgets/home_action_grid.dart';
import 'add_work_log_screen.dart'; // Yoki papka tuzilishiga qarab: import '../screens/add_work_log_screen.dart';
class OrderStatus {
  // Status kalitlari (Bazada xuddi shunday saqlanadi)
  static const pending = 'pending';
  static const material = 'material';
  static const assembly = 'assembly';
  static const delivery = 'delivery';
  static const completed = 'completed';
  static const canceled = 'canceled';

  // UI da ko'rsatiladigan chiroyli nomlari (Tarjimalar)
  static String getText(String? status) {
    switch (status) {
      case pending: return 'Kutilmoqda';
      case material: return 'Kesish/Material';
      case assembly: return "Yig'ish";
      case delivery: return "O'rnatish";
      case completed: return 'Yakunlandi';
      case canceled: return 'Bekor qilindi';
      default: return 'Noma\'lum';
    }
  }

  // Status ranglari
  static Color getColor(String? status) {
    switch (status) {
      case pending: return Colors.orange;
      case material: return Colors.purple;
      case assembly: return Colors.blue;
      case delivery: return Colors.teal;
      case completed: return Colors.green;
      case canceled: return Colors.red;
      default: return Colors.grey;
    }
  }
  
  // Aktiv (hali yopilmagan) zakazlarni tekshirish uchun yordamchi ro'yxat
  static const activeStatuses = [pending, material, assembly, delivery];
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // --- Yangi Ruxsatlar Tizimi O'zgaruvchilari ---
  bool _isSuperAdmin = false;
  String _userName = '';
  String _userRoleType = 'worker'; // aup yoki worker
  String _positionName = 'Hodim';  // Masalan: Kassir, Menejer
  
  Map<String, dynamic> _customPermissions = {};
  Map<String, dynamic> _rolePermissions = {};

  // --- Kassa va Statistika ---
  double _displayEarned = 0;
  double _displayWithdrawn = 0;
  double _secondaryBalance = 0; 
  int _statsCount = 0;
  int _totalOrders = 0;
  int _activeOrders = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // ─── 1. RUXSATLARNI TEKSHIRUVCHI FUNKSIYA (MIYA) ──────────────
  bool hasPermission(String action) {
    if (_isSuperAdmin) return true; // Superadminga hamma eshiklar ochiq!
    
    // Avval shaxsiy (override) ruxsatlarni tekshiramiz
    if (_customPermissions.containsKey(action)) {
      return _customPermissions[action] == true;
    }
    
    // Agar shaxsiy yo'q bo'lsa, lavozimi bo'yicha ruxsatni ko'ramiz
    if (_rolePermissions.containsKey(action)) {
      return _rolePermissions[action] == true;
    }
    
    return false; // Hech qayerda ruxsat topilmasa - yopiq!
  }

  // ─── 2. MA'LUMOT VA RUXSATLARNI BAZADAN TORTISH ───────────────
  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // app_roles jadvali bilan qo'shib (join qilib) chaqiramiz
      final profile = await _supabase
          .from('profiles')
          .select('*, app_roles(name, role_type, permissions)')
          .eq('id', user.id)
          .single();

      _userName = profile['full_name'] ?? 'Foydalanuvchi';
      _isSuperAdmin = profile['is_super_admin'] ?? false;
      
      // JSON ruxsatlarni o'qib olamiz
      _customPermissions = profile['custom_permissions'] ?? {};
      
      if (profile['app_roles'] != null) {
        _positionName = profile['app_roles']['name'];
        _userRoleType = profile['app_roles']['role_type'];
        _rolePermissions = profile['app_roles']['permissions'] ?? {};
      }

      // Kassa va Moliya ma'lumotlarini yuklash...
      if (hasPermission('can_view_finance') || _isSuperAdmin) {
        // RAHBARIYAT YOKI KASSIR UCHUN
        final orders = await _supabase.from('orders').select('total_price, status');
        final withdrawals = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');
            
        double totalIncome = 0;
        double totalPaid = 0;
        int active = 0;
        
        for (var o in orders) {
          totalIncome += (o['total_price'] ?? 0).toDouble();
          
          // Agar status "activeStatuses" ro'yxatida bo'lsa (ya'ni pending, material, assembly yoki delivery)
          if (OrderStatus.activeStatuses.contains(o['status'])) {
             active++;
          }
        }
        for (var w in withdrawals) totalPaid += (w['amount'] ?? 0).toDouble();

        final workers = await _supabase.from('profiles').select('id').eq('is_super_admin', false);
        final allWorks = await _supabase.from('work_logs').select('total_sum').eq('is_approved', true);
        double totalWorksSum = 0;
        for (var w in allWorks) totalWorksSum += (w['total_sum'] ?? 0).toDouble();
        
        if (mounted) {
          setState(() {
            _displayEarned = totalIncome;
            _displayWithdrawn = totalPaid;
            _totalOrders = orders.length;
            _activeOrders = active;
            _secondaryBalance = (totalWorksSum - totalPaid) > 0 ? (totalWorksSum - totalPaid) : 0; 
            _statsCount = workers.length; 
          });
        }
      } else {
        // ODDIY HODIMLAR UCHUN (faqat o'zini pulini ko'radi)
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
            _secondaryBalance = earned - paid; 
            _statsCount = works.length; 
          });
        }
      }
    } catch (e) {
      debugPrint("Yuklashda xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return "Xayrli tong";
    if (h < 17) return "Xayrli kun";
    return "Xayrli kech";
  }

  void _showWithdrawDialog() {
    // Avans so'rash kodi (o'zgarishsiz qoldi)
    // ... (joyni tejash uchun bu yerni qisqartirdim, o'zingizdagi kodni ishlataverasiz)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAllData,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  children: [
                    // 1. Tepa qism (Endi salomlashganda lavozimi ham ko'rinadi)
                    HomeHeader(greeting: _greeting, userName: "$_userName ($_positionName)"),
                    const SizedBox(height: 25),
                    
                    // 2. Katta Kassa Kartasi 
                    // (Agar can_view_finance ruxsati bo'lsa korxona kassasi chiqadi, yo'qsa hodim kartasi)
                    BalanceCard(
                      role: (hasPermission('can_view_finance') || _isSuperAdmin) ? 'admin' : 'worker', 
                      mainBalance: _displayEarned - _displayWithdrawn,
                      income: _displayEarned,
                      expense: _displayWithdrawn, 
                      secondaryBalance: _secondaryBalance, 
                      statsCount: _statsCount, 
                    ),
                    const SizedBox(height: 25),
                    
                    // 3. Tezkor Tugmalar 
                    // (Bu yerni ham ruxsatlarga bog'lab yuboramiz)
                    HomeActionGrid(
                      isAdmin: _isSuperAdmin || _userRoleType == 'aup',
                      // Yig'ilgan ruxsatlar tekshiriladi: Superadminmi yoki can_manage_users huquqi bormi?
                      canManageUsers: _isSuperAdmin || hasPermission('can_manage_users'),
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
