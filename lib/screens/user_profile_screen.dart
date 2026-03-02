import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_themes.dart';
import 'user_transactions_screen.dart';
import '../services/encryption_service.dart';

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
  
  double _balance = 0;
  bool _canSeeBalance = false;
  bool _isAup = false;

  bool _allowDefaultAi = false; 
  bool _isSuperAdmin = false;
  final _groqKeyCtrl = TextEditingController();
  final _geminiKeyCtrl = TextEditingController();
  final _customPromptCtrl = TextEditingController();

  // XATOLIK TUZATILDI: Hamma matnlar "" ichiga olindi
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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = _supabase.auth.currentUser!.id;
      final targetId = widget.userId ?? currentUserId;
      _isMe = targetId == currentUserId;

      final data = await _supabase.from('profiles').select('*, app_roles(*)').eq('id', targetId).single();
      _userData = data;
      _isSuperAdmin = data['is_super_admin'] ?? false;
      _isAup = data['app_roles']?['role_type'] == 'aup';
      _canSeeBalance = _isMe || _isSuperAdmin || _isAup;

      if (_isMe) {
        _groqKeyCtrl.text = EncryptionService.decryptText(data['groq_api_key'] ?? '');
        _geminiKeyCtrl.text = EncryptionService.decryptText(data['gemini_api_key'] ?? '');
        _customPromptCtrl.text = data['custom_ai_prompt'] ?? '';
      }

      if (_isSuperAdmin) {
        final aiSetting = await _supabase.from('app_settings').select('value').eq('key', 'allow_default_ai').maybeSingle();
        if (aiSetting != null) _allowDefaultAi = aiSetting['value'] == 'true';
      }

      final works = await _supabase.from('work_logs').select('total_sum').eq('worker_id', targetId).eq('is_approved', true);
      final withdraws = await _supabase.from('withdrawals').select('amount').eq('worker_id', targetId).eq('status', 'approved');
      double earned = 0; for (var w in works) earned += (w['total_sum'] ?? 0).toDouble();
      double paid = 0; for (var w in withdraws) paid += (w['amount'] ?? 0).toDouble();
      _balance = earned - paid;
    } catch (e) { debugPrint("Xato: $e"); } 
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  String _formatMoney(double amount) => "${NumberFormat('#,###').format(amount).replaceAll(',', ' ')} so'm";
  Widget _buildAdminAiToggle() {
    if (!_isSuperAdmin) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: SwitchListTile(
        title: const Text("Tizim AI kalitlaridan foydalanishga ruxsat", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
        subtitle: const Text("Yoqilsa, o'z kaliti yo'q xodimlar ham sizning kalitingizdan foydalana oladi.", style: TextStyle(fontSize: 12)),
        value: _allowDefaultAi,
        activeColor: Colors.orange,
        onChanged: (val) async {
          setState(() => _allowDefaultAi = val);
          await _supabase.from('app_settings').upsert({'key': 'allow_default_ai', 'value': val.toString()});
          
          // XATOLIK TUZATILDI: Interpolatsiya matni alohida o'zgaruvchiga olindi
          final statusText = val ? "yoqildi" : "o'chirildi";
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tizim AI ruxsati $statusText!")));
        },
      ),
    );
  }

  Widget _buildAISettings() {
    if (!_isMe) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("🤖 SHAXSIY AI SOZLAMALARI", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 12),
          TextField(controller: _groqKeyCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Groq API Key", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _geminiKeyCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Gemini API Key", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _customPromptCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Shaxsiy qo'shimcha ko'rsatma (Prompt)", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.security), label: const Text("Xavfsiz Saqlash"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                final encGroq = EncryptionService.encryptText(_groqKeyCtrl.text.trim());
                final encGemini = EncryptionService.encryptText(_geminiKeyCtrl.text.trim());
                await _supabase.from('profiles').update({
                  'groq_api_key': encGroq, 'gemini_api_key': encGemini, 'custom_ai_prompt': _customPromptCtrl.text.trim(),
                }).eq('id', _supabase.auth.currentUser!.id);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saqlandi!")));
              },
            ),
          ),
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
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E5BFF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profil")),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_userData?['full_name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          if (_canSeeBalance) Text("Balans: ${_formatMoney(_balance)}", style: const TextStyle(fontSize: 18, color: Colors.green)),
          const SizedBox(height: 20),
          _buildActionButton(), 
          const SizedBox(height: 20),
          _buildAdminAiToggle(), 
          _buildAISettings(),    
        ],
      ),
    );
  }
}
