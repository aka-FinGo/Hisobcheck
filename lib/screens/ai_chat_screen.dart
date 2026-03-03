import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'ai_settings_screen.dart';
import '../services/ai_service.dart';
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

  bool _isGroqModelNotFound(http.Response res) {
    if (res.statusCode != 404) return false;
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final code = body?["error"]?["code"]?.toString();
      if (code == "model_not_found") return true;
      final msg = body?["error"]?["message"]?.toString().toLowerCase() ?? "";
      return msg.contains("does not exist") || msg.contains("do not have access");
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> _groqChat({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userText,
  }) {
    final trimmedModel = model.trim();
    final isCompound = trimmedModel == "groq/compound";

    final body = <String, dynamic>{
      "model": trimmedModel,
      "messages": [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": userText},
      ],
    };

    if (isCompound) {
      body["compound_custom"] = {
        "tools": {
          "enabled_tools": ["web_search", "code_interpreter", "visit_website"]
        }
      };
    } else {
      // groq/compound does NOT support OpenAI-style tool calling.
      body["tools"] = [
        {
          "type": "function",
          "function": {
            "name": "generate_report",
            "parameters": {
              "type": "object",
              "properties": {
                "format": {
                  "type": "string",
                  "enum": ["pdf", "excel", "jpg"]
                },
                "data_type": {
                  "type": "string",
                  "enum": ["finance", "orders", "remnants"]
                },
                "from_date": {
                  "type": "string"
                },
                "to_date": {
                  "type": "string"
                }
              },
              "required": ["format", "data_type"]
            }
          }
        }
      ];
    }

    return http.post(
      Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );
  }

  Future<String> _getDbContext(bool isAdmin) async {
    try {
      if (!isAdmin) return "Foydalanuvchi huquqlari cheklangan.";
      final res = await _supabase.from("ai_erp_summary").select().single();
      return "BALANS: ${res['total_balance']} so'm. ZAKAZLAR: ${res['pending_orders_count']} ta kutilmoqda. OMBOR: ${res['total_items_quantity']} dona qoldiq.";
    } catch (e) {
      return "Baza bilan bog'lanishda xato.";
    }
  }

  Future<void> _executeToolCall(
    String format,
    String dataType, {
    String? fromDate,
    String? toDate,
  }) async {
    setState(() => _messages.add({"role": "ai", "text": "⚙️ $dataType bo'yicha $format hisoboti tayyorlanmoqda...", "model": "System"}));
    try {
      List<Map<String, dynamic>> data = [];
      List<String> columns = [];
      if (dataType == "finance") {
        data = List<Map<String, dynamic>>.from(await _supabase.from("company_finance").select("*").limit(50));
        columns = ["id", "type", "amount", "category", "description"];
      } else if (dataType == "orders") {
        data = List<Map<String, dynamic>>.from(await _supabase.from("orders").select("*").limit(50));
        columns = ["order_number", "status", "total_price", "project_name"];
      } else if (dataType == "remnants") {
        data = List<Map<String, dynamic>>.from(await _supabase.from("remnants").select("*").limit(50));
        columns = ["color_name", "thickness", "quantity", "width", "height"];
      }

      if (format == "pdf") await ReportGeneratorService.generatePdf(data, dataType.toUpperCase(), columns);
      if (format == "excel") await ReportGeneratorService.generateExcel(data, dataType.toUpperCase(), columns);
      if (format == "jpg") await ReportGeneratorService.generateImageInfographic({"Jami": "${data.length}"}, dataType.toUpperCase());
    } catch (e) {
      setState(() => _messages.add({"role": "ai", "text": "❌ Xato: $e", "model": "Error"}));
    }
  }
  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _messages.add({"role": "user", "text": text, "model": "User"}); _isTyping = true; });
    _msgCtrl.clear();

    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from("profiles").select("*").eq("id", userId).single();
      final bool isAdmin = profile["is_super_admin"] ?? false;
      final settings = await _supabase.from("app_settings").select("*");
      
      String groqMdl = (settings.firstWhere((s) => s["key"] == "groq_model_name", orElse: () => {"value": "groq/compound"})["value"] ?? "groq/compound").toString().trim();
      String geminiMdl = (settings.firstWhere((s) => s["key"] == "gemini_model_name", orElse: () => {"value": "gemini-2.5-flash"})["value"] ?? "gemini-2.5-flash").toString().trim();
      String globalPrm = (settings.firstWhere((s) => s["key"] == "global_system_prompt", orElse: () => {"value": ""})["value"] ?? "").toString();
      
      // AI keys: personal -> (optional) admin default keys from --dart-define
      String groqK = "";
      String geminiK = "";
      try {
        final keys = await AiService().getValidAiKeys();
        groqK = keys["groq"] ?? "";
        geminiK = keys["gemini"] ?? "";
      } catch (_) {
        // Fallback to legacy per-profile keys (older behavior)
        groqK = EncryptionService.decryptText(profile["groq_api_key"] ?? "");
        geminiK = EncryptionService.decryptText(profile["gemini_api_key"] ?? "");
      }
      String ctx = await _getDbContext(isAdmin);

      final prompt = "Siz Aristokrat Mebel ERP yordamchisisisiz. $globalPrm\n$ctx";
      bool success = false;

      if (groqK.isNotEmpty) {
        final triedModels = <String>[
          groqMdl,
          if (groqMdl == "groq/compound") "llama-3.3-70b-versatile",
          "llama-3.1-8b-instant",
        ].map((m) => m.trim()).where((m) => m.isNotEmpty).toSet().toList();

        http.Response? lastRes;
        String usedModel = groqMdl;

        for (final mdl in triedModels) {
          usedModel = mdl;
          final res = await _groqChat(apiKey: groqK, model: mdl, systemPrompt: prompt, userText: text);
          lastRes = res;

          if (res.statusCode == 200) {
            final data = jsonDecode(utf8.decode(res.bodyBytes));
            final msg = data["choices"][0]["message"];
          if (msg["tool_calls"] != null) {
            final args = jsonDecode(msg["tool_calls"][0]["function"]["arguments"]);
            await _executeToolCall(
              args["format"],
              args["data_type"],
              fromDate: args["from_date"],
              toDate: args["to_date"],
            );
            } else {
              setState(() => _messages.add({"role": "ai", "text": msg["content"], "model": "⚡ $usedModel"}));
            }
            success = true;
            break;
          }

          if (!_isGroqModelNotFound(res)) break;
        }

        if (!success && lastRes != null) {
          final res = lastRes;
          setState(() => _messages.add({"role": "ai", "text": "Groq Xatosi (${res!.statusCode}): ${res.body}", "model": "Error"}));
        }
      }

      if (!success && geminiK.isNotEmpty) {
        final res = await http.post(Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/$geminiMdl:generateContent?key=$geminiK"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"systemInstruction": {"parts": [{"text": prompt}]}, "contents": [{"parts": [{"text": text}]}]})
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          setState(() => _messages.add({"role": "ai", "text": data["candidates"][0]["content"]["parts"][0]["text"], "model": "✨ $geminiMdl"}));
        } else {
          setState(() => _messages.add({"role": "ai", "text": "Gemini Xatosi (${res.statusCode}): ${res.body}", "model": "Error"}));
        }
      }
    } catch (e) {
      setState(() => _messages.add({"role": "ai", "text": "Exception: $e", "model": "Exception"}));
    } finally { if (mounted) setState(() => _isTyping = false); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Aristokrat AI"), actions: [IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSettingsScreen())))]),
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
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: isUser ? Colors.purple : Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(msg["text"]!, style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
                        if (!isUser && msg["model"] != null)
                          Padding(padding: const EdgeInsets.only(top: 4), child: Text(msg["model"]!, style: const TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isTyping) const LinearProgressIndicator(),
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _msgCtrl, decoration: const InputDecoration(hintText: "Savol..."), onSubmitted: (_) => _sendMessage())),
                IconButton(icon: const Icon(Icons.send, color: Colors.purple), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
