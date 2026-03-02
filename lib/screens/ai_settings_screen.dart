import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/encryption_service.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSuperAdmin = false;
  bool _allowDefaultAi = false;

  final _groqKeyCtrl = TextEditingController();
  final _geminiKeyCtrl = TextEditingController();
  final _customPromptCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      final profile = await _supabase.from('profiles').select('is_super_admin, groq_api_key, gemini_api_key, custom_ai_prompt').eq('id', user!.id).single();

      _isSuperAdmin = profile['is_super_admin'] ?? false;
      
      // Kalitlarni parolini yechib olamiz
      _groqKeyCtrl.text = EncryptionService.decryptText(profile['groq_api_key'] ?? '');
      _geminiKeyCtrl.text = EncryptionService.decryptText(profile['gemini_api_key'] ?? '');
      _customPromptCtrl.text = profile['custom_ai_prompt'] ?? '';

      // Agar admin bo'lsa, global ruxsatni o'qiymiz
      if (_isSuperAdmin) {
        final aiSetting = await _supabase.from('app_settings').select('value').eq('key', 'allow_default_ai').maybeSingle();
        if (aiSetting != null) _allowDefaultAi = aiSetting['value'] == 'true';
      }
    } catch (e) {
      debugPrint("Sozlamalarni yuklashda xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    // Kiritilgan kalitlarni shifrlaymiz
    final encGroq = EncryptionService.encryptText(_groqKeyCtrl.text.trim());
    final encGemini = EncryptionService.encryptText(_geminiKeyCtrl.text.trim());
    
    await _supabase.from('profiles').update({
      'groq_api_key': encGroq,
      'gemini_api_key': encGemini,
      'custom_ai_prompt': _customPromptCtrl.text.trim(),
    }).eq('id', _supabase.auth.currentUser!.id);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI Sozlamalari xavfsiz saqlandi!")));
    }
  }

  Widget _buildAdminToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: Colors.orange.withOpacity(0.5))
      ),
      child: SwitchListTile(
        title: const Text("Tizim kalitlaridan ommaviy foydalanish", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
        subtitle: const Text("Yoqilsa, o'z kalitiga ega bo'lmagan xodimlar ham sizning GitHub'ga kiritgan kalitlaringizdan foydalana oladi.", style: TextStyle(fontSize: 12)),
        value: _allowDefaultAi,
        activeColor: Colors.orange,
        onChanged: (val) async {
          setState(() => _allowDefaultAi = val);
          await _supabase.from('app_settings').upsert({'key': 'allow_default_ai', 'value': val.toString()});
          
          final statusText = val ? "yoqildi" : "o'chirildi";
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ommaviy ruxsat $statusText!")));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Sozlamalari")),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isSuperAdmin) _buildAdminToggle(),
          
          const Text("Shaxsiy API Kalitlar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          TextField(controller: _groqKeyCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Groq API Key", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _geminiKeyCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Gemini API Key", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _customPromptCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Maxsus Prompt (Qo'shimcha ko'rsatma)", border: OutlineInputBorder(), hintText: "Masalan: Menga qisqa javob ber...")),
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.security), 
              label: const Text("Saqlash", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: _saveSettings,
            ),
          ),
        ],
      ),
    );
  }
}
