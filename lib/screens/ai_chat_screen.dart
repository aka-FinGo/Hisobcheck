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
  final List<Map<String, String>> _messages = [];
  final _supabase = Supabase.instance.client;
  bool _isTyping = false;

  // --- 1. DINAMIK KONTEKST YIG'UVCHI ---
  Future<String> _getDbContext(bool isAdmin) async {
    String ctx = "JORIY KORXONA HOLATI (Faqat so'ralsa shu raqamlarni ayt):\n";
    try {
      if (isAdmin) {
        final orders = await _supabase.from('orders').select('status');
        int pending = orders.where((o) => o['status'] == 'pending').length;
        int completed = orders.where((o) => o['status'] == 'completed').length;
        ctx += "- Zakazlar: $pending ta kutilmoqda, $completed ta bitgan.\n";

        final finance = await _supabase.from('company_finance').select('amount, type');
        double balance = 0;
        for (var f in finance) balance += (f['type'] == 'Kirim' ? (f['amount'] ?? 0) : -(f['amount'] ?? 0));
        ctx += "- Kassa balansi: $balance so'm.\n";
      } else {
        ctx += "- Ushbu xodimda kassa va umumiy zakazlarni ko'rish ruxsati yo'q.\n";
      }
    } catch (e) {
      ctx += "- Baza bilan bog'lanishda vaqtinchalik uzilish.\n";
    }
    return ctx;
  }

  // --- 2. FUNKSIYA CHAQRUVINI BAJARUVCHI (TRIGGER) ---
  Future<void> _executeToolCall(String format, String dataType) async {
    setState(() => _messages.add({"role": "ai", "text": "⚙️ Buyruq qabul qilindi. $dataType bo'yicha $format hisoboti tayyorlanmoqda..."}));
    
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
      setState(() => _messages.add({"role": "ai", "text": "❌ Hisobot tayyorlashda xatolik: $e"}));
    }
  }
  // --- 3. AI AGENT SO'ROVI VA MIYASI ---
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

      if (groqKey.isEmpty && geminiKey.isEmpty) {
        setState(() => _messages.add({"role": "ai", "text": "API kalit topilmadi. Sozlamalardan kalit kiriting!"}));
        return;
      }

      final globalPromptRes = await _supabase.from('app_settings').select('value').eq('key', 'global_system_prompt').maybeSingle();
      final globalPrompt = globalPromptRes != null ? globalPromptRes['value'] : '';
      
      final dbContext = await _getDbContext(isSuperAdmin);

      // MAKSIMAL KUCHAYTIRILGAN PROMPT
      final strictSystemPrompt = """Sen 'Aristokrat Mebel' ERP tizimining arxitektori aka_FinGo yaratgan rasmiy AI yordamchisisan.
QAT'IY QOIDALAR:
1. Javobingni imkon qadar qisqa, 1-2 gap bilan londa ber. Tokenlarni teja.
2. "Salom", "Albatta", "Xo'sh", "Tushundim" kabi ortiqcha suvlarni umuman ishlatma. To'g'ridan-to'g'ri javobga o't.
3. Foydalanuvchi hisobot, Excel, PDF yoki rasm (Infografika) so'rasa, matn yozib o'tirma, darhol 'generate_report' funksiyasini chaqir!
4. Qo'shimcha admin ko'rsatmalari: $globalPrompt ${profile['custom_ai_prompt'] ?? ''}
$dbContext""";

      bool groqSuccess = false;

      // GROQ API (Function Calling bilan)
      if (groqKey.isNotEmpty) {
        final groqRes = await http.post(
          Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
          headers: {"Authorization": "Bearer $groqKey", "Content-Type": "application/json"},
          body: jsonEncode({
            "model": "llama3-groq-70b-8192-tool-use-preview", // Aniq Tools ishlatadigan maxsus model
            "messages": [
              {"role": "system", "content": strictSystemPrompt},
              {"role": "user", "content": text}
            ],
            "tools": [{
              "type": "function",
              "function": {
                "name": "generate_report",
                "description": "Foydalanuvchi PDF, Excel yoki JPG/Rasm hisobot so'raganda ushbu funksiyani chaqir.",
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
          final message = data['choices'][0]['message'];
          
          if (message['tool_calls'] != null && message['tool_calls'].isNotEmpty) {
            final toolCall = message['tool_calls'][0];
            final args = jsonDecode(toolCall['function']['arguments']);
            await _executeToolCall(args['format'], args['data_type']);
          } else {
            setState(() => _messages.add({"role": "ai", "text": message['content']}));
          }
          groqSuccess = true;
        }
      }

      // GEMINI FALLBACK (Agar Groq ishlamasa)
      if (!groqSuccess && geminiKey.isNotEmpty) {
        final geminiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$geminiKey";
        final geminiRes = await http.post(
          Uri.parse(geminiUrl), headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "systemInstruction": {"parts": [{"text": strictSystemPrompt}]},
            "contents": [{"parts": [{"text": text}]}]
          })
        );
        if (geminiRes.statusCode == 200) {
          final data = jsonDecode(utf8.decode(geminiRes.bodyBytes));
          setState(() => _messages.add({"role": "ai", "text": data['candidates'][0]['content']['parts'][0]['text']}));
        }
      }
    } catch (e) {
      setState(() => _messages.add({"role": "ai", "text": "Tizim xatosi: $e"}));
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
                  hintText: "Suhbatlashing yoki hisobot so'rang...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Theme.of(context).cardTheme.color,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (_) => _isTyping ? null : _sendMessage(),
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
