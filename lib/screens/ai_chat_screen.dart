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

  // --- HAQIQIY MIYA (API ga so'rov) ---
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
      final profile = await _supabase.from('profiles').select('is_super_admin, groq_api_key, custom_ai_prompt').eq('id', userId).single();
      
      // 1. Foydalanuvchi shaxsiy kalitini o'qiymiz
      String apiKey = EncryptionService.decryptText(profile['groq_api_key'] ?? '');
      
      // 2. Agar o'zida kalit bo'lmasa, Admin ommaviy ruxsat berganligini tekshiramiz
      if (apiKey.isEmpty) {
        final setting = await _supabase.from('app_settings').select('value').eq('key', 'allow_default_ai').maybeSingle();
        if (setting != null && setting['value'] == 'true') {
          apiKey = const String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
        }
      }

      // 3. Ikkisi ham yo'q bo'lsa
      if (apiKey.isEmpty) {
        setState(() => _messages.add({"role": "ai", "text": "API kalit topilmadi! Iltimos, tepa o'ng burchakdagi sozlamalardan o'z kalitingizni kiriting."}));
        return;
      }

      // 4. ERP Standart Prompt + Foydalanuvchi Custom Prompti
      final systemPrompt = "Sen 'Aristokrat Mebel' korxonasining rasmiy ERP AI yordamchisisan. Faqat mebel ishlab chiqarish, moliya, xodimlar va buyurtmalar bo'yicha qisqa va aniq javob ber. " + (profile['custom_ai_prompt'] ?? '');

      // 5. Groq API ga yuborish
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json"
        },
        body: jsonEncode({
          "model": "llama3-70b-8192", // Groq'ning eng kuchli modeli
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": text}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final aiReply = data['choices'][0]['message']['content'];
        setState(() => _messages.add({"role": "ai", "text": aiReply}));
      } else {
        setState(() => _messages.add({"role": "ai", "text": "Groq xatosi: HTTP ${response.statusCode}"}));
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
