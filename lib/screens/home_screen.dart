import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'manage_users_screen.dart';   
import 'clients_screen.dart';        
import 'stats_screen.dart'; // Hisobotlar sahifasi
import 'user_profile_screen.dart';
import '../widgets/balance_card.dart'; 
import '../widgets/reload_button.dart';
// YANGI VIDJETLAR IMPORTI
import '../widgets/menu_button.dart';
import '../widgets/mini_stat_card.dart';
import '../widgets/big_action_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  String _userRole = 'worker';
  String _userName = '';
  
  // Balans
  double _displayEarned = 0;   
  double _displayWithdrawn = 0; 
  
  // Admin stats
  int _totalOrders = 0;
  int _activeOrders = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase.from('profiles').select().eq('id', user.id).single();
      _userRole = profile['role'] ?? 'worker';
      _userName = profile['full_name'] ?? 'Foydalanuvchi';

      if (_userRole == 'admin') {
        final orders = await _supabase.from('orders').select('total_price, status');
        final withdrawals = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');

        double totalIncome = 0;
        double totalPaid = 0;

        for (var o in orders) totalIncome += (o['total_price'] ?? 0).toDouble();
        for (var w in withdrawals) totalPaid += (w['amount'] ?? 0).toDouble();

        if (mounted) {
          setState(() {
            _displayEarned = totalIncome;    
            _displayWithdrawn = totalPaid;   
            _totalOrders = orders.length;
            _activeOrders = orders.where((o) => o['status'] != 'completed' && o['status'] != 'canceled').length;
            _isLoading = false;
          });
        }
      } else {
        final works = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id);
        final withdraws = await _supabase.from('withdrawals').select('amount').eq('user_id', user.id).eq('status', 'approved');

        double earned = 0;
        double paid = 0;

        for (var w in works) earned += (w['total_sum'] ?? 0).toDouble();
        for (var w in withdraws) paid += (w['amount'] ?? 0).toDouble();

        if (mounted) {
          setState(() {
            _displayEarned = earned;
            _displayWithdrawn = paid;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (Dialog funksiyalari o'sha-o'sha qoladi: _showWorkDialog, _showWithdrawDialog)
  // Joyni tejash uchun ularni qisqartirib yozmadim, eski koddan ko'chirib qo'yishingiz mumkin.
  // Lekin BigActionButton ishlashi uchun ular kerak bo'ladi.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // Juda och kulrang fon
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: Stack(
              children: [
                // ASOSIY SCROLL QISMI
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // Pastdan joy qoldiramiz (Tugma uchun)
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. HEADER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Xush kelibsiz,", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                              Text(_userName, style: const TextStyle(color: Color(0xFF2D3142), fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen())),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.blue.shade100,
                              child: Text(_userName.isNotEmpty ? _userName[0] : "A", style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 25),

                      // 2. ADMIN UCHUN KICHIK STATISTIKA
                      if (_userRole == 'admin') ...[
                        Row(
                          children: [
                            MiniStatCard(
                              title: "Jami Zakaz", 
                              value: "$_totalOrders", 
                              color: Colors.blue, 
                              icon: Icons.assignment
                            ),
                            const SizedBox(width: 15),
                            MiniStatCard(
                              title: "Jarayonda", 
                              value: "$_activeOrders", 
                              color: Colors.orange, 
                              icon: Icons.timelapse
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 3. BALANS KARTASI
                      BalanceCard(
                        earned: _displayEarned,
                        withdrawn: _displayWithdrawn,
                        role: _userRole,
                        onStatsTap: () {
                          if (_userRole == 'admin') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
                          }
                        },
                      ),

                      const SizedBox(height: 30),
                      const Text("Bo'limlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                      const SizedBox(height: 15),

                      // 4. MENYU GRID (TUGMALAR)
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 1.1, // Kvadratroq shakl
                        children: [
                          MenuButton(
                            title: "Mijozlar",
                            icon: Icons.people_outline,
                            color: Colors.orange,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen())),
                          ),
                          
                          if (_userRole == 'admin') ...[
                            MenuButton(
                              title: "Hisobotlar",
                              icon: Icons.bar_chart,
                              color: Colors.indigo,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
                            ),
                            MenuButton(
                              title: "Xodimlar",
                              icon: Icons.manage_accounts_outlined,
                              color: Colors.purple,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
                            ),
                          ],

                          if (_userRole != 'admin')
                            MenuButton(
                              title: "Pul so'rash",
                              icon: Icons.account_balance_wallet_outlined,
                              color: Colors.green,
                              // onTap: _showWithdrawDialog, // Bu funksiyani eski koddan qo'shing
                              onTap: () {}, 
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 5. PASTKI KATTA TUGMA (FLOATING ACTION)
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: _userRole != 'admin' 
                    ? BigActionButton(
                        text: "ISH TOPSHIRISH",
                        icon: Icons.add_task,
                        color: const Color(0xFF2E5BFF),
                        // onPressed: _showWorkDialog, // Eski koddan funksiyani qo'shing
                        onPressed: () {},
                      )
                    : BigActionButton(
                        text: "YANGI MIJOZ QO'SHISH",
                        icon: Icons.person_add,
                        color: const Color(0xFF00C853),
                        onPressed: () {
                           // Mijoz qo'shish dialogini ochish
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen()));
                        },
                      ),
                ),
              ],
            ),
          ),
    );
  }
}
