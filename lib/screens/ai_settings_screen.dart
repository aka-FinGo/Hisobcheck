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
  final _globalPromptCtrl = TextEditingController();
  final _groqModelCtrl = TextEditingController();
  final _geminiModelCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      final profile = await _supabase.from("profiles").select("is_super_admin, groq_api_key, gemini_api_key, custom_ai_prompt").eq("id", user!.id).single();

      _isSuperAdmin = profile["is_super_admin"] ?? false;
      _groqKeyCtrl.text = EncryptionService.decryptText(profile["groq_api_key"] ?? "");
      _geminiKeyCtrl.text = EncryptionService.decryptText(profile["gemini_api_key"] ?? "");
      _customPromptCtrl.text = profile["custom_ai_prompt"] ?? "";

      if (_isSuperAdmin) {
        final settings = await _supabase.from("app_settings").select("*");
        for (var s in settings) {
          if (s["key"] == "allow_default_ai") _allowDefaultAi = s["value"] == "true";
          if (s["key"] == "global_system_prompt") _globalPromptCtrl.text = s["value"] ?? "";
          if (s["key"] == "groq_model_name") _groqModelCtrl.text = s["value"] ?? "groq/compound";
          if (s["key"] == "gemini_model_name") _geminiModelCtrl.text = s["value"] ?? "gemini-2.5-flash";
        }
      }
    } catch (e) {
      debugPrint("Sozlamalarni yuklashda xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final encGroq = EncryptionService.encryptText(_groqKeyCtrl.text.trim());
      final encGemini = EncryptionService.encryptText(_geminiKeyCtrl.text.trim());
      
      await _supabase.from("profiles").update({
        "groq_api_key": encGroq,
        "gemini_api_key": encGemini,
        "custom_ai_prompt": _customPromptCtrl.text.trim(),
      }).eq("id", _supabase.auth.currentUser!.id);

      if (_isSuperAdmin) {
        await _supabase.from("app_settings").upsert({"key": "global_system_prompt", "value": _globalPromptCtrl.text.trim()});
        await _supabase.from("app_settings").upsert({"key": "groq_model_name", "value": _groqModelCtrl.text.trim()});
        await _supabase.from("app_settings").upsert({"key": "gemini_model_name", "value": _geminiModelCtrl.text.trim()});
      }
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sozlamalar saqlandi!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saqlashda xato: $e")));
    }
  }
  Widget _buildAdminPanel() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: Colors.orange.withOpacity(0.5))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("👑 ADMIN BOSHQARUVI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 15),
          TextField(controller: _groqModelCtrl, decoration: const InputDecoration(labelText: "Groq Model Nomi (masalan: groq/compound yoki llama-3.3-70b-versatile)", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _geminiModelCtrl, decoration: const InputDecoration(labelText: "Gemini Model Nomi (masalan: gemini-2.5-flash)", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _globalPromptCtrl, maxLines: 4, decoration: const InputDecoration(labelText: "Global System Prompt", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Ommaviy API kalitlarini yoqish"),
            value: _allowDefaultAi,
            onChanged: (val) async {
              setState(() => _allowDefaultAi = val);
              await _supabase.from("app_settings").upsert({"key": "allow_default_ai", "value": val.toString()});
            },
          ),
        ],
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
          if (_isSuperAdmin) _buildAdminPanel(),
          const Text("Shaxsiy API Kalitlar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          TextField(controller: _groqKeyCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Groq API Key", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _geminiKeyCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Gemini API Key", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _customPromptCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Shaxsiy Prompt", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save), 
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
