import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'ai_settings_screen.dart';
import '../services/encryption_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final _supabase = Supabase.instance.client;
  bool _isTyping = false;

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isTyping = true;
    });
    _msgCtrl.clear();

    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('is_super_admin, groq_api_key, gemini_api_key, custom_ai_prompt').eq('id', userId).single();
      
      String groqKey = EncryptionService.decryptText(profile['groq_api_key'] ?? '');
      String geminiKey = EncryptionService.decryptText(profile['gemini_api_key'] ?? '');
      
      if (groqKey.isEmpty && geminiKey.isEmpty) {
        final setting = await _supabase.from('app_settings').select('value').eq('key', 'allow_default_ai').maybeSingle();
        if (setting != null && setting['value'] == 'true') {
          groqKey = const String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
          geminiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
        }
      }

      if (groqKey.isEmpty && geminiKey.isEmpty) {
        setState(() => _messages.add({
          "role": "ai", 
          "text": "API kalit topilmadi!\n\nYO'RIQNOMA:\n1. Tepa o'ng burchakdagi (⚙️) belgisini bosing.\n2. Groq kaliti uchun: console.groq.com saytidan API oling.\n3. Gemini kaliti uchun: aistudio.google.com saytidan oling.\n4. Kalitlarni kiritib 'Saqlash' tugmasini bosing."
        }));
        return;
      }

      final systemPrompt = "Sen 'Aristokrat Mebel' ERP AI yordamchisisan. Qisqa, aniq va ortiqcha suvsiz javob ber. " + (profile['custom_ai_prompt'] ?? '');
      bool groqSuccess = false;

      // 1. GROQ COMPOUND API (Birlamchi)
      if (groqKey.isNotEmpty) {
        final groqRes = await http.post(
          Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
          headers: {"Authorization": "Bearer $groqKey", "Content-Type": "application/json"},
          body: jsonEncode({
            "model": "groq/compound",
            "messages": [
              {"role": "system", "content": systemPrompt},
              {"role": "user", "content": text}
            ],
            "temperature": 1.0,
            "compound_custom": {
              "tools": { "enabled_tools": ["web_search", "code_interpreter"] }
            }
          }),
        );
        if (groqRes.statusCode == 200) {
          final data = jsonDecode(utf8.decode(groqRes.bodyBytes));
          final aiReply = data['choices'][0]['message']['content'];
          setState(() => _messages.add({"role": "ai", "text": aiReply}));
          groqSuccess = true;
        }
      }

      // 2. GEMINI 2.5 FLASH API (Fallback - Groq ishlamasa)
      if (!groqSuccess && geminiKey.isNotEmpty) {
        final geminiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$geminiKey";
        final geminiRes = await http.post(
          Uri.parse(geminiUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "systemInstruction": { "parts": [{"text": systemPrompt}] },
            "contents": [{"parts": [{"text": text}]}]
          })
        );
        if (geminiRes.statusCode == 200) {
          final data = jsonDecode(utf8.decode(geminiRes.bodyBytes));
          final aiReply = data['candidates'][0]['content']['parts'][0]['text'];
          setState(() => _messages.add({"role": "ai", "text": aiReply}));
        } else {
          setState(() => _messages.add({"role": "ai", "text": "Xatolik: Groq ham, Gemini ham javob bermadi."}));
        }
      }
    } catch (e) {
      setState(() => _messages.add({"role": "ai", "text": "Ulanishda xato yuz berdi: $e"}));
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Aristokrat AI", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSettingsScreen())),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty 
              ? Center(child: Text("Suhbatni boshlang...", style: TextStyle(color: Colors.grey.shade500)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg["role"] == "user";
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.purple : Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(msg["text"]!, style: TextStyle(color: isUser ? Colors.white : null)),
                      ),
                    );
                  },
                ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Align(alignment: Alignment.centerLeft, child: CircularProgressIndicator(color: Colors.purple)),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                decoration: InputDecoration(
                  hintText: "Suhbatlashing...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Theme.of(context).cardTheme.color,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.purple,
              radius: 24,
              child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _isTyping ? null : _sendMessage),
            ),
          ],
        ),
      ),
    );
  }
}
