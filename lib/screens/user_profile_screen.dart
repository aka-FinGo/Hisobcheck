import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../theme/app_themes.dart';
import 'user_transactions_screen.dart';
import 'ai_chat_screen.dart'; // AI Chat uchun ulandi

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

  // XATOLIK TUZATILDI: Hamma matnlar "" (qo'shtirnoq) ichiga olindi
  final Map<String, String> _allPerms = {
    'can_view_finance': "Kassani ko'rish",
    'can_add_order': "Zakaz qo'shish",
    'can_manage_users': "Xodimlarni boshqarish",
    'can_manage_clients': "Mijozlarni boshqarish",
    'can_add_work_log': "Ish hisobotini kiritish",
    'can_view_all_orders': "Barcha zakazlarni ko'rish",
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

  String _formatMoney(double amount) => "${NumberFormat('#,###').format(amount).replaceAll(',', ' ')} so'm";
  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
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
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
      ),
    );
  }

  // YANGI QO'SHILDI: Faqat o'zimning profilimda chiqadigan AI tugma
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
        ),
      ),
    );
  }

  Widget _buildPermissionsCard() {
    final customPerms = Map<String, dynamic>.from(_userData!['custom_permissions'] ?? {});
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ruxsatnomalar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ..._allPerms.entries.map((entry) {
              final hasPerm = customPerms[entry.key] == true;
              return ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(hasPerm ? Icons.check_circle : Icons.cancel, color: hasPerm ? Colors.green : Colors.red), title: Text(entry.value));
            }),
          ],
        ),
      ),
    );
  }

  void _showAdminEditDialog() {
    int? selectedRoleId = _userData!['position_id'];
    Map<String, dynamic> customPerms = Map<String, dynamic>.from(_userData!['custom_permissions'] ?? {});
    final salaryCtrl = TextEditingController(text: _userData!['custom_salary']?.toString() ?? '');
    final bonusCtrl = TextEditingController(text: _userData!['custom_bonus_per_m2']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Xodimni tahrirlash"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(value: selectedRoleId, decoration: const InputDecoration(labelText: "Lavozimi"), items: _roles.map((r) => DropdownMenuItem<int>(value: r['id'], child: Text(r['name']))).toList(), onChanged: (v) => setDialogState(() => selectedRoleId = v)),
                const SizedBox(height: 10),
                TextField(controller: salaryCtrl, decoration: const InputDecoration(labelText: "Maxsus oylik (ixtiyoriy)"), keyboardType: TextInputType.number),
                TextField(controller: bonusCtrl, decoration: const InputDecoration(labelText: "Bonus % (ixtiyoriy)"), keyboardType: TextInputType.number),
                const Divider(),
                const Text("Qo'shimcha ruxsatlar", style: TextStyle(fontWeight: FontWeight.bold)),
                ..._allPerms.entries.map((entry) {
                  return CheckboxListTile(title: Text(entry.value, style: const TextStyle(fontSize: 14)), value: customPerms[entry.key] == true, onChanged: (val) => setDialogState(() => customPerms[entry.key] = val));
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor")),
            ElevatedButton(
              onPressed: () async {
                await _supabase.from('profiles').update({'position_id': selectedRoleId, 'custom_salary': double.tryParse(salaryCtrl.text), 'custom_bonus_per_m2': double.tryParse(bonusCtrl.text), 'custom_permissions': customPerms}).eq('id', _userData!['id']);
                Navigator.pop(ctx);
                _loadUserData();
              },
              child: const Text("Saqlash"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil"),
        actions: [
          if (!_isMe && (_supabase.auth.currentUser!.id == widget.userId || _userData?['is_super_admin'] == true))
             IconButton(icon: const Icon(Icons.edit), onPressed: _showAdminEditDialog),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_userData?['full_name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(_userData?['app_roles']?['name'] ?? 'Lavozim belgilanmagan', style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 20),
          if (_canSeeBalance) ...[
            _buildBalanceCard(),
            const SizedBox(height: 16),
            _buildActionButton(),
            _buildAiChatButton(), // TUGMA QO'SHILDI
            const SizedBox(height: 20),
          ],
          if (_userData?['custom_permissions'] != null)
            _buildPermissionsCard(),
        ],
      ),
    );
  }
}
