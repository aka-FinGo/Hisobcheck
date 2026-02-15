import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'admin_approvals.dart';
import 'add_withdrawal.dart';
import 'history_screen.dart'; 
import 'wallet_screen.dart';// SHU IMPORT JUDA MUHIM!

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _userName = '';
  String _userRole = 'worker';
  String _userId = '';

  double _totalEarned = 0;
  double _totalWithdrawn = 0;
  double _pendingAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      _userId = user.id;

      final profile = await _supabase.from('profiles').select().eq('id', _userId).single();
      
      final workLogs = await _supabase.from('work_logs').select().eq('worker_id', _userId);
      final withdrawals = await _supabase.from('withdrawals').select().eq('worker_id', _userId);

      double earned = 0;
      double pending = 0;
      for (var log in workLogs) {
        if (log['is_approved'] == true) {
          earned += (log['total_sum'] ?? 0).toDouble();
        } else {
          pending += (log['total_sum'] ?? 0).toDouble();
        }
      }

      double withdrawn = 0;
      for (var w in withdrawals) {
        withdrawn += (w['amount'] ?? 0).toDouble();
      }

      setState(() {
        _userName = profile['full_name'] ?? 'Xodim';
        _userRole = profile['role'] ?? 'worker';
        _totalEarned = earned;
        _totalWithdrawn = withdrawn;
        _pendingAmount = pending;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

    @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(_userRole == 'admin' ? "Admin: $_userName" : "Hisob: $_userName"),
        actions: [
          IconButton(onPressed: _handleSignOut, icon: const Icon(Icons.logout, color: Colors.red)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildBalanceCard(),
              const SizedBox(height: 20),
              
              // 1-QATOR: ISH VA TARIX
              Row(
                children: [
                  _buildMenuBtn("Ish Qo'shish", Icons.add_circle, Colors.blue, _showWorkDialog),
                  const SizedBox(width: 10),
                  _buildMenuBtn("Tarix", Icons.history, Colors.grey.shade700, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HistoryScreen()),
                    );
                  }),
                ],
              ),
              
              const SizedBox(height: 10), // Qatorlar orasidagi masofa

              // 2-QATOR: HAMYON (MANA SHU YERDA!)
              Row(
                children: [
                  _buildMenuBtn("Hamyon", Icons.account_balance_wallet, Colors.green.shade700, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WalletScreen()),
                    );
                  }),
                  const SizedBox(width: 10),
                  const Expanded(child: SizedBox()), // Joyni teng taqsimlash uchun bo'sh katak
                ],
              ),
              
              // ADMIN BO'LIMI
              if (_userRole == 'admin') ...[
                const SizedBox(height: 30),
                const Divider(),
                const Text("ADMIN BOSHQARUVI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _buildMenuBtn("Tasdiqlash", Icons.fact_check, Colors.purple, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalsScreen()));
                    }),
                    const SizedBox(width: 10),
                    _buildMenuBtn("Pul Berish", Icons.payments, Colors.green, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWithdrawalScreen()));
                    }),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
