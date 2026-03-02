import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/encryption_service.dart';
import 'user_transactions_screen.dart';

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

  // --- AI SOZLAMALARI UCHUN CONTROLLERLAR ---
  final _groqKeyCtrl = TextEditingController();
  final _geminiKeyCtrl = TextEditingController();
  final _customPromptCtrl = TextEditingController();

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

      // Profilni yuklash
      final data = await _supabase.from('profiles').select('*, app_roles(*)').eq('id', targetId).single();
      _userData = data;

      // Agar o'zimning profilim bo'lsa, AI kalitlarni o'qib, UI ga qo'yamiz
      if (_isMe) {
        _groqKeyCtrl.text = EncryptionService.decryptText(data['groq_api_key'] ?? '');
        _geminiKeyCtrl.text = EncryptionService.decryptText(data['gemini_api_key'] ?? '');
        _customPromptCtrl.text = data['custom_ai_prompt'] ?? '';
      }

      // Balans hisoblash (Kiritilgan sodda mantiq)
      final works = await _supabase.from('work_logs').select('total_sum').eq('worker_id', targetId).eq('is_approved', true);
      final withdraws = await _supabase.from('withdrawals').select('amount').eq('worker_id', targetId).eq('status', 'approved');
      
      double earned = 0; for (var w in works) earned += (w['total_sum'] ?? 0).toDouble();
      double paid = 0; for (var w in withdraws) paid += (w['amount'] ?? 0).toDouble();
      _balance = earned - paid;

    } catch (e) {
      debugPrint("Profil yuklashda xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMoney(double amount) => "${NumberFormat("#,###").format(amount).replaceAll(',', ' ')} so'm";
  // --- AI YO'RIQNOMASI (TUTORIAL) ---
  void _showAITutorial() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.smart_toy, color: Colors.blue), SizedBox(width: 10), Text("AI Yordamchi")]),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Tizimdan bepul foydalanishingiz mumkin, ammo AI yordamchi uchun o'z API kalitingizni kiritishingiz shart (BYOK tizimi)."),
              SizedBox(height: 15),
              Text("🔑 Groq API (Tavsiya etiladi)", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("1. console.groq.com saytiga kiring.\n2. API Keys bo'limidan yangi kalit oling.\n3. Model: groq/compound (Avtomat)"),
              SizedBox(height: 15),
              Text("🔑 Gemini API", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("1. aistudio.google.com saytiga kiring.\n2. API kalit yarating.\n3. Model: gemini-2.5-flash (Avtomat)"),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tushundim")),
        ],
      ),
    );
  }

  // --- AI SOZLAMALARI BLOKI ---
  Widget _buildAISettings() {
    if (!_isMe) return const SizedBox.shrink(); // Boshqalar birovning kalitini ko'rolmaydi

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("🤖 AI YORDAMCHI SOZLAMALARI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 15),
          TextField(controller: _groqKeyCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Groq API Key", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _geminiKeyCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Gemini API Key", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _customPromptCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Shaxsiy AI ko'rsatmalaringiz (Prompt)", border: OutlineInputBorder(), hintText: "Masalan: Menga qisqa va faqat raqamlarda javob ber...")),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.security), label: const Text("Xavfsiz Saqlash"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                // Kalitlarni shifrlab bazaga saqlaymiz
                final encGroq = EncryptionService.encryptText(_groqKeyCtrl.text.trim());
                final encGemini = EncryptionService.encryptText(_geminiKeyCtrl.text.trim());
                await _supabase.from('profiles').update({
                  'groq_api_key': encGroq, 'gemini_api_key': encGemini, 'custom_ai_prompt': _customPromptCtrl.text.trim(),
                }).eq('id', _supabase.auth.currentUser!.id);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI sozlamalari shifrlanib saqlandi!")));
              },
            ),
          ),
        ],
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
          // Profil asosi (Ism, Balans, Tarix tugmalari) - O'zingizdagi dizaynni qoldiring
          Text(_userData?['full_name'] ?? 'Foydalanuvchi', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text("Balans: ${_formatMoney(_balance)}", style: const TextStyle(fontSize: 18, color: Colors.green)),
          const SizedBox(height: 25),
          
          // AI CHAT TUGMASI (GATEKEEPER)
          if (_isMe)
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome), label: const Text("AI Yordamchi bilan suhbat"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.purple, foregroundColor: Colors.white),
              onPressed: () {
                if (_groqKeyCtrl.text.trim().isEmpty && _geminiKeyCtrl.text.trim().isEmpty) {
                  _showAITutorial(); // Kalit yo'q -> Yo'riqnoma chiqadi
                } else {
                  // Kalit bor -> Chat ekraniga o'tadi
                  // Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatScreen()));
                }
              },
            ),
          const SizedBox(height: 20),
          _buildAISettings(),
        ],
      ),
    );
  }
}
