import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';

import '../theme/theme_provider.dart';
import 'clients_screen.dart';
import 'orders_list_screen.dart';
import 'stats_screen.dart';
import 'user_profile_screen.dart';
import 'add_work_log_screen.dart';
import 'admin_approvals.dart';
import 'manage_users_screen.dart';
import 'manage_roles_screen.dart';

class OrderStatus {
  static const pending = 'pending';
  static const material = 'material';
  static const assembly = 'assembly';
  static const delivery = 'delivery';
  static const completed = 'completed';
  static const canceled = 'canceled';

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

  bool _isSuperAdmin = false;
  String _userName = '';
  String _userRoleType = 'worker';
  String _positionName = 'Hodim';

  Map<String, dynamic> _customPermissions = {};
  Map<String, dynamic> _rolePermissions = {};

  double _displayEarned = 0;
  double _displayWithdrawn = 0;
  double _secondaryBalance = 0;
  int _statsCount = 0;
  int _totalOrders = 0;
  int _activeOrders = 0;

  int _pendingApprovals = 0;
  int _totalClientsCount = 0;
  int _newClientsCount = 0;

  final NumberFormat _fmt = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  bool hasPermission(String action) {
    if (_isSuperAdmin) return true;
    if (_customPermissions.containsKey(action)) return _customPermissions[action] == true;
    if (_rolePermissions.containsKey(action)) return _rolePermissions[action] == true;
    return false;
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase.from('profiles').select('*, app_roles(*)').eq('id', user.id).single();

      _isSuperAdmin = profile['is_super_admin'] ?? false;
      _userName = profile['full_name'] ?? 'Foydalanuvchi';
      _userRoleType = profile['role'] ?? 'worker';
      
      if (profile['app_roles'] != null) {
        _positionName = profile['app_roles']['name'] ?? 'Hodim';
        _rolePermissions = profile['app_roles']['permissions'] ?? {};
      }
      if (profile['custom_permissions'] != null) {
        _customPermissions = profile['custom_permissions'] ?? {};
      }

      // Admin or specific permission to view finance
      if (hasPermission('can_view_finance') || _isSuperAdmin) {
        final orders = await _supabase.from('orders').select('total_price, status');
        final withdrawals = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');
        final pendingWorks = await _supabase.from('work_logs').select('id').eq('is_approved', false);
        final pendingAvans = await _supabase.from('withdrawals').select('id').eq('status', 'pending');
        final clientsRes = await _supabase.from('clients').select('id, created_at');
        final allWorks = await _supabase.from('work_logs').select('total_sum').eq('is_approved', true);

        double totalInc = 0;
        int active = 0;
        for (var o in orders) {
          totalInc += (o['total_price'] ?? 0).toDouble();
          if (OrderStatus.activeStatuses.contains(o['status'])) active++;
        }
        
        double totalPaid = 0;
        for (var w in withdrawals) totalPaid += (w['amount'] ?? 0).toDouble();

        double totalWorksSum = 0;
        for (var w in allWorks) totalWorksSum += (w['total_sum'] ?? 0).toDouble();

        final dayAgo = DateTime.now().subtract(const Duration(days: 1));
        final recentOnes = clientsRes.where((c) => DateTime.parse(c['created_at']).isAfter(dayAgo)).length;

        if (mounted) {
          setState(() {
            _displayEarned = totalInc;
            _displayWithdrawn = totalPaid;
            _totalOrders = orders.length;
            _activeOrders = active;
            _secondaryBalance = (totalWorksSum - totalPaid) > 0 ? (totalWorksSum - totalPaid) : 0;
            _pendingApprovals = pendingWorks.length + pendingAvans.length;
            _totalClientsCount = clientsRes.length;
            _newClientsCount = recentOnes;
          });
        }
      } else {
        // Worker
        final works = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id).eq('is_approved', true);
        final withdraws = await _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved');
        
        // Let's get general orders stats for worker too, so the dashboard works
        final activeO = await _supabase.from('orders').select('id, status');
        int activeCount = 0;
        for (var o in activeO) {
          if (OrderStatus.activeStatuses.contains(o['status'])) activeCount++;
        }

        double earned = 0;
        double paid = 0;
        for (var w in works) earned += (w['total_sum'] ?? 0).toDouble();
        for (var w in withdraws) paid += (w['amount'] ?? 0).toDouble();

        if (mounted) {
          setState(() {
            _displayEarned = earned;
            _displayWithdrawn = paid;
            _secondaryBalance = earned - paid;
            _statsCount = works.length; // Bajarilgan ishlar soni
            _pendingApprovals = 0;
            _totalOrders = activeO.length;
            _activeOrders = activeCount;
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

  String _fmtMoney(double v) => '${_fmt.format(v).replaceAll(',', ' ')}';

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.currentMode == AppThemeMode.dark;
    final isGlass = themeProvider.currentMode == AppThemeMode.glass;
    
    // Fallback colors for light mode to match the exact mockup
    final bgColor = isDark ? const Color(0xFF121212) : (isGlass ? Colors.transparent : const Color(0xFFFAFAFA));
    final textColor = isDark || isGlass ? Colors.white : Colors.black87;
    final cardBgColor = isDark ? const Color(0xFF1E1E1E) : (isGlass ? Colors.white.withOpacity(0.1) : Colors.white);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadAllData,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 30),
              children: [
                // 1. TOP BAR
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
                          const SizedBox(height: 2),
                          Text("$_userName ($_positionName)", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 19)),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: textColor),
                            onPressed: () {
                              themeProvider.setThemeMode(isDark ? AppThemeMode.light : AppThemeMode.dark);
                            },
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: const Color(0xFFE3F2FD),
                            child: Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : 'A', 
                              style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                          )
                        ],
                      )
                    ],
                  ),
                ),

                // 2. MAIN CARD
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: (hasPermission('can_view_finance') || _isSuperAdmin)
                      ? _buildAdminCard()
                      : _buildWorkerCard(),
                ),

                const SizedBox(height: 20),

                // 3. ISH TOPSHIRISH BUTTON
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E5BFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 24),
                      label: const Text("Bajargan ishni topshirish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        if (hasPermission('can_add_work_log') || _userRoleType == 'worker') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWorkLogScreen())).then((_) => _loadAllData());
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu amal uchun ruxsatingiz yo'q.")));
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 4. JAMI ZAKAZ / JARAYONDA CARDS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMiniStatCard(
                          title: "Jami zakaz", 
                          value: "$_totalOrders", 
                          icon: Icons.receipt_long, 
                          iconColor: const Color(0xFF3F51B5), 
                          bgColor: const Color(0xFFE8EAF6),
                          cardBg: cardBgColor,
                          textColor: textColor,
                        )
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildMiniStatCard(
                          title: "Jarayonda", 
                          value: "$_activeOrders", 
                          icon: Icons.hourglass_top, 
                          iconColor: const Color(0xFFFF9800), 
                          bgColor: const Color(0xFFFFF3E0),
                          cardBg: cardBgColor,
                          textColor: textColor,
                        )
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 5. TEZKOR AMALLAR GRID
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Tezkor amallar", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 15,
                        crossAxisSpacing: 15,
                        children: _buildGridCards(cardBgColor, textColor),
                      )
                    ],
                  ),
                ),
              ],
            )
        )
      )
    );
  }

  // --- KORXONA KASSASI (Admin) ---
  Widget _buildAdminCard() {
    double sofFoyda = _displayEarned - _displayWithdrawn;
    
    Widget front = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A4073), Color(0xFF1CB5A3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1CB5A3).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
        ]
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("KORXONA KASSASI", style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                Icon(Icons.memory, color: Colors.amber[600], size: 28),
              ],
            ),
            const SizedBox(height: 25),
            const Text("Umumiy Kassa (Sof foyda)", style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 5),
            Text("${_fmtMoney(sofFoyda)} so'm", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Daromad", style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11)),
                    const SizedBox(height: 4),
                    Text("${_fmtMoney(_displayEarned)} so'm", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Xarajatlar", style: TextStyle(color: Color(0xFFFF5252), fontSize: 11)),
                    const SizedBox(height: 4),
                    Text("${_fmtMoney(_displayWithdrawn)} so'm", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );

    Widget back = Container(
      height: 200, // Matching typical card height
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A4073), Color(0xFF1CB5A3)],
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1CB5A3).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
        ]
      ),
      child: Stack(
        children: [
          Positioned(
            top: 30, left: 0, right: 0,
            child: Container(color: Colors.black87, height: 45),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end, // Align to bottom
              children: [
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Ma'sul shaxs", style: TextStyle(color: Colors.white54, fontSize: 10)),
                        const SizedBox(height: 4),
                        Text(_userName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                      ],
                    ),
                    const Text("ARISTOKRAT", style: TextStyle(color: Colors.white24, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                  ]
                )
              ],
            ),
          )
        ],
      )
    );

    return GestureFlipCard(
      axis: FlipAxis.horizontal,
      enableController: false,
      animationDuration: const Duration(milliseconds: 600),
      frontWidget: front,
      backWidget: back,
    );
  }

  // --- SHAXSIY MAOSHINGIZ (Worker) ---
  Widget _buildWorkerCard() {
    double maosh = _displayEarned - _displayWithdrawn;
    
    Widget front = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1B29), Color(0xFF133C85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF133C85).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))
        ]
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("SHAXSIY HISOBLANGI", style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                Icon(Icons.contactless, color: Colors.white70, size: 24),
              ],
            ),
            const SizedBox(height: 35),
            const Text("Joriy balans", style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 5),
            Text("${_fmtMoney(maosh)} so'm", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const Spacer(flex: 1),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_userName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                const Text("ARISTOKRAT", style: TextStyle(color: Colors.white24, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
              ],
            )
          ],
        ),
      ),
    );

    Widget back = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1B29), Color(0xFF133C85)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF133C85).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))
        ]
      ),
      child: Stack(
        children: [
          // Magnetic stripe effect
          Positioned(
            top: 30, left: 0, right: 0,
            child: Container(color: Colors.black87, height: 45),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60), // Spacer for stripe
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Oq blok (Shaxsiy maosh)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("MAOSHINGIZ", style: TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text("${_fmtMoney(maosh)} so'm", style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    // Bajarilgan ishlar count 
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("Bajarilgan ishlar", style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text("$_statsCount", style: const TextStyle(color: Colors.amber, fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                      ],
                    )
                  ],
                )
              ],
            ),
          )
        ],
      )
    );

    return GestureFlipCard(
      axis: FlipAxis.horizontal,
      enableController: false,
      animationDuration: const Duration(milliseconds: 600),
      frontWidget: front,
      backWidget: back,
    );
  }

  Widget _buildMiniStatCard({required String title, required String value, required IconData icon, required Color iconColor, required Color bgColor, required Color cardBg, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardBg == Colors.white ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: bgColor,
            radius: 20,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  List<Widget> _buildGridCards(Color cardBgColor, Color textColor) {
    List<Widget> cards = [];

    // Tasdiqlashlar (Usually Admin only, but we show conditionally based on user role/permissions)
    if (_isSuperAdmin || hasPermission('can_view_finance') || hasPermission('can_manage_users')) {
      cards.add(
        _buildGridCardItem(
          title: "Tasdiqlashlar",
          icon: Icons.checklist_rtl_rounded,
          iconColor: Colors.redAccent,
          iconBg: Colors.red.withOpacity(0.1),
          badge: _pendingApprovals,
          cardBg: cardBgColor,
          textColor: textColor,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalsScreen())).then((_) => _loadAllData());
          }
        )
      );
    } else {
      // Allow worker to see their own history or specific page, or just keep placeholder to match 4-grid from mockup
      cards.add(
        _buildGridCardItem(
          title: "Mening ishlarim",
          icon: Icons.checklist_rtl_rounded,
          iconColor: Colors.redAccent,
          iconBg: Colors.red.withOpacity(0.1),
          badge: 0,
          cardBg: cardBgColor,
          textColor: textColor,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tez orada ishga tushadi")));
          }
        )
      );
    }

    // Mijozlar
    cards.add(
      _buildGridCardItem(
        title: "Mijozlar",
        icon: Icons.people_alt,
        iconColor: Colors.blue,
        iconBg: Colors.blue.withOpacity(0.1),
        badge: 0,
        cardBg: cardBgColor,
        textColor: textColor,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen())).then((_) => _loadAllData());
        }
      )
    );

    // Hisobotlar (Stats)
    cards.add(
      _buildGridCardItem(
        title: "Hisobotlar",
        icon: Icons.bar_chart_rounded,
        iconColor: Colors.purple,
        iconBg: Colors.purple.withOpacity(0.1),
        badge: 0,
        cardBg: cardBgColor,
        textColor: textColor,
        onTap: () {
          if (_isSuperAdmin || hasPermission('can_view_finance')) {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
          } else {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Faqat rahbarlar uchun!")));
          }
        }
      )
    );

    // Hodimlar/Sozlamalar
    cards.add(
      _buildGridCardItem(
        title: "Sozlamalar",
        icon: Icons.manage_accounts,
        iconColor: Colors.amber[700]!,
        iconBg: Colors.amber.withOpacity(0.15),
        badge: 0,
        cardBg: cardBgColor,
        textColor: textColor,
        onTap: () {
          if (_isSuperAdmin || hasPermission('can_manage_users')) {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen()));
          } else {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen()));
          }
        }
      )
    );

    return cards;
  }

  Widget _buildGridCardItem({
    required String title, required IconData icon, required Color iconColor, required Color iconBg, 
    required int badge, required Color cardBg, required Color textColor, required VoidCallback onTap}) {
    return Stack(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: cardBg == Colors.white ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))] : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: iconBg,
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(height: 12),
                Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            top: 8, right: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF44336),
                shape: BoxShape.circle,
                border: Border.all(color: cardBg, width: 2),
              ),
              child: Text(
                "$badge", 
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
              ),
            ),
          )
      ],
    );
  }
}
