import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'ai_settings_screen.dart';
import '../services/encryption_service.dart';
import '../services/report_generator_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  // Model nomi saqlanishi uchun 'model' key qo'shildi
  final List<Map<String, String>> _messages = [];
  final _supabase = Supabase.instance.client;
  bool _isTyping = false;

  Future<String> _getDbContext(bool isAdmin) async {
    String ctx = "JORIY KORXONA HOLATI (Faqat so'ralsa shu raqamlarni ayt):\n";
    try {
      if (isAdmin) {
        // SQL View orqali barcha hisob-kitobni bitta so'rovda olamiz
        final res = await _supabase.from('ai_erp_summary').select().single();
        
        ctx += "- Kassa balansi: ${res['total_balance']} so'm.\n";
        ctx += "- Zakazlar: ${res['pending_orders_count']} ta kutilmoqda, ${res['completed_orders_count']} ta bitgan.\n";
        ctx += "- Ombor: ${res['total_remnants_count']} turdagi material, jami ${res['total_items_quantity']} dona qoldiq bor.\n";
      } else {
        ctx += "- Foydalanuvchi cheklangan huquqlarga ega. Faqat umumiy savollarga javob ber.\n";
      }
    } catch (e) {
      ctx += "- Ma'lumotlarni bazadan olishda xatolik yuz berdi. Faqat umumiy yordam ber.\n";
    }
    return ctx;
  }

  Future<void> _executeToolCall(String format, String dataType) async {
    setState(() => _messages.add({
      "role": "ai", 
      "text": "⚙️ Buyruq qabul qilindi. $dataType bo'yicha $format hisoboti tayyorlanmoqda...",
      "model": "System"
    }));
    
    try {
      List<Map<String, dynamic>> data = [];
      List<String> columns = [];

      if (dataType == "finance") {
        final res = await _supabase.from('company_finance').select('*').order('created_at', ascending: false).limit(50);
        data = List<Map<String, dynamic>>.from(res);
        columns = ["id", "type", "amount", "category", "description"];
      } else if (dataType == "orders") {
        final res = await _supabase.from('orders').select('*').order('created_at', ascending: false).limit(50);
        data = List<Map<String, dynamic>>.from(res);
        columns = ["order_number", "status", "total_price", "project_name"];
      } else if (dataType == "remnants") {
        final res = await _supabase.from('remnants').select('*').limit(50);
        data = List<Map<String, dynamic>>.from(res);
        columns = ["color_name", "thickness", "quantity", "width", "height"];
      }

      if (format == "pdf") {
        await ReportGeneratorService.generatePdf(data, dataType.toUpperCase(), columns);
      } else if (format == "excel") {
        await ReportGeneratorService.generateExcel(data, dataType.toUpperCase(), columns);
      } else if (format == "jpg") {
        Map<String, String> stats = {"Jami yozuvlar": "${data.length} ta", "Hisobot turi": dataType.toUpperCase()};
        await ReportGeneratorService.generateImageInfographic(stats, dataType.toUpperCase());
      }
    } catch (e) {
      setState(() => _messages.add({"role": "ai", "text": "❌ Xatolik: $e", "model": "Error"}));
    }
  }
  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text, "model": "User"});
      _isTyping = true;
    });
    _msgCtrl.clear();

    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('is_super_admin, groq_api_key, gemini_api_key, custom_ai_prompt').eq('id', userId).single();
      final bool isSuperAdmin = profile['is_super_admin'] ?? false;
      
      String groqKey = EncryptionService.decryptText(profile['groq_api_key'] ?? '');
      String geminiKey = EncryptionService.decryptText(profile['gemini_api_key'] ?? '');
      
      if (groqKey.isEmpty && geminiKey.isEmpty) {
        final setting = await _supabase.from('app_settings').select('value').eq('key', 'allow_default_ai').maybeSingle();
        if (setting != null && setting['value'] == 'true') {
          groqKey = const String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
          geminiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
        }
      }

      final globalPromptRes = await _supabase.from('app_settings').select('value').eq('key', 'global_system_prompt').maybeSingle();
      final globalPrompt = globalPromptRes != null ? globalPromptRes['value'] : '';
      final dbContext = await _getDbContext(isSuperAdmin);

      final strictSystemPrompt = """Sen 'Aristokrat Mebel' AI yordamchisisan.
QOIDALAR: 
1. Qisqa javob ber. 
2. Hisobot so'ralsa 'generate_report' funksiyasini ishlat.
3. Admin ko'rsatmasi: $globalPrompt
4. Kontekst: $dbContext""";

      bool groqSuccess = false;

      if (groqKey.isNotEmpty) {
        final groqRes = await http.post(
          Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
          headers: {"Authorization": "Bearer $groqKey", "Content-Type": "application/json"},
          body: jsonEncode({
            "model": "llama3-groq-70b-8192-tool-use-preview",
            "messages": [{"role": "system", "content": strictSystemPrompt}, {"role": "user", "content": text}],
            "tools": [{
              "type": "function",
              "function": {
                "name": "generate_report",
                "parameters": {
                  "type": "object",
                  "properties": {
                    "format": {"type": "string", "enum": ["pdf", "excel", "jpg"]},
                    "data_type": {"type": "string", "enum": ["finance", "orders", "remnants"]}
                  },
                  "required": ["format", "data_type"]
                }
              }
            }]
          }),
        );

        if (groqRes.statusCode == 200) {
          final data = jsonDecode(utf8.decode(groqRes.bodyBytes));
          final msg = data['choices'][0]['message'];
          if (msg['tool_calls'] != null) {
            final args = jsonDecode(msg['tool_calls'][0]['function']['arguments']);
            await _executeToolCall(args['format'], args['data_type']);
          } else {
            setState(() => _messages.add({"role": "ai", "text": msg['content'], "model": "⚡ Groq"}));
          }
          groqSuccess = true;
        }
      }

      if (!groqSuccess && geminiKey.isNotEmpty) {
        final geminiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiKey";
        final geminiRes = await http.post(Uri.parse(geminiUrl), headers: {"Content-Type": "application/json"},
          body: jsonEncode({"systemInstruction": {"parts": [{"text": strictSystemPrompt}]}, "contents": [{"parts": [{"text": text}]}]})
        );
        if (geminiRes.statusCode == 200) {
          final data = jsonDecode(utf8.decode(geminiRes.bodyBytes));
          final aiReply = data['candidates'][0]['content']['parts'][0]['text'];
          setState(() => _messages.add({"role": "ai", "text": aiReply, "model": "✨ Gemini"}));
        }
      }
    } catch (e) {
      setState(() => _messages.add({"role": "ai", "text": "Xato: $e", "model": "Error"}));
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Aristokrat AI", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSettingsScreen())))],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["role"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.purple : Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end, // Indikatorni o'ngga surish
                      children: [
                        Text(msg["text"]!, style: TextStyle(color: isUser ? Colors.white : null, fontSize: 15)),
                        if (!isUser && msg["model"] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            msg["model"]!, 
                            style: TextStyle(color: isUser ? Colors.white70 : Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isTyping) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator(minHeight: 2)),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(child: TextField(controller: _msgCtrl, decoration: const InputDecoration(hintText: "Savol bering..."), onSubmitted: (_) => _sendMessage())),
          IconButton(icon: const Icon(Icons.send, color: Colors.purple), onPressed: _sendMessage),
        ],
      ),
    );
  }
}
