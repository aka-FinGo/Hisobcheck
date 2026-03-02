import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../theme/app_themes.dart';
import 'user_transactions_screen.dart';
import 'ai_chat_screen.dart'; // YANGI QO'SHILDI

class UserProfileScreen extends StatefulWidget {
  final String? userId; 
  const UserProfileScreen({super.key, this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isMe = false;
  Map<String, dynamic>? _userData;
  List<dynamic> _roles = [];
  
  double _balance = 0;
  bool _canSeeBalance = false;
  bool _isAup = false;

  final Map<String, String> _allPerms = {
    'can_view_finance': 'Kassani ko\\'rish',
    'can_add_order': 'Zakaz qo\\'shish',
    'can_manage_users': 'Xodimlarni boshqarish',
    'can_manage_clients': 'Mijozlarni boshqarish',
    'can_add_work_log': 'Ish hisobotini kiritish',
    'can_view_all_orders': 'Barcha zakazlarni ko\\'rish',
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = _supabase.auth.currentUser!.id;
      final targetId = widget.userId ?? currentUserId;
      _isMe = (targetId == currentUserId);

      final data = await _supabase.from('profiles').select('*, app_roles(*)').eq('id', targetId).single();
      _userData = data;

      final isSuperAdmin = data['is_super_admin'] ?? false;
      final roleType = data['app_roles']?['role_type'] ?? 'worker';
      _isAup = (roleType == 'aup');

      _canSeeBalance = _isMe || isSuperAdmin || _isAup;

      final roleRes = await _supabase.from('app_roles').select('*');
      _roles = roleRes;

      if (_canSeeBalance) {
        final works = await _supabase.from('work_logs').select('total_sum').eq('worker_id', targetId).eq('is_approved', true);
        final withdraws = await _supabase.from('withdrawals').select('amount').eq('worker_id', targetId).eq('status', 'approved');
        
        double earned = 0;
        for (var w in works) earned += (w['total_sum'] ?? 0).toDouble();
        
        double paid = 0;
        for (var w in withdraws) paid += (w['amount'] ?? 0).toDouble();

        _balance = earned - paid;
      }
    } catch (e) {
      debugPrint("Profil yuklashda xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMoney(double amount) => "${NumberFormat("#,###").format(amount).replaceAll(',', ' ')} so'm";
  Widget _buildBalanceCard() {
    final theme = Theme.of(context);
    final statsTheme = theme.extension<StatsTheme>()!;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Hozirgi balans", style: TextStyle(color: Colors.white70, fontSize: 14)),
              Icon(Icons.account_balance_wallet_outlined, color: Colors.white.withOpacity(0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_formatMoney(_balance), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity, height: 55,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserTransactionsScreen(userId: _userData!['id'], fullName: _userData!['full_name']))),
        icon: const Icon(Icons.history_rounded),
        label: const Text("Amallar / Tarix", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
        ),
      ),
    );
  }

  // YANGI QO'SHILGAN TUGMA (Faqat profil egasiga ko'rinadi)
  Widget _buildAiChatButton() {
    if (!_isMe) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: SizedBox(
        width: double.infinity, height: 55,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
          icon: const Icon(Icons.auto_awesome),
          label: const Text("AI Yordamchi bilan suhbat", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
          ),
        ),
      ),
    );
  }
