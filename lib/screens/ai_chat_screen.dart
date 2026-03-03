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

  Future<String> _getDbContext(String userId, bool isAdmin) async {
    try {
      final summary = await _supabase.from("ai_erp_summary").select().single();
      final num companyBalanceNum = (summary["total_balance"] ?? 0) as num;
      final num pendingOrdersNum = (summary["pending_orders_count"] ?? 0) as num;
      final num totalItemsNum = (summary["total_items_quantity"] ?? 0) as num;

      // Foydalanuvchining shaxsiy balansi: bajarilgan ishlar - olgan avanslar
      final works = await _supabase
          .from("work_logs")
          .select("total_sum")
          .eq("worker_id", userId)
          .eq("is_approved", true);
      final withdraws = await _supabase
          .from("withdrawals")
          .select("amount")
          .eq("worker_id", userId)
          .eq("status", "approved");

      double earned = 0;
      double paid = 0;
      for (final w in works) {
        final num v = (w["total_sum"] ?? 0) as num;
        earned += v.toDouble();
      }
      for (final w in withdraws) {
        final num v = (w["amount"] ?? 0) as num;
        paid += v.toDouble();
      }
      final personalBalance = earned - paid;

      return "KORXONA BALANSI: ${companyBalanceNum.toStringAsFixed(0)} so'm. "
          "KUTILAYOTGAN ZAKAZLAR: ${pendingOrdersNum.toInt()} ta. "
          "OMBOR QOLDIQ: ${totalItemsNum.toInt()} dona.\n"
          "SIZNING SHAXSIY BALANSINGIZ: ${personalBalance.toStringAsFixed(0)} so'm (bajarilgan ishlar minus tasdiqlangan avanslar).";
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
      String ctx = await _getDbContext(userId, isAdmin);

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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Aristokrat AI"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceVariant.withOpacity(0.8),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg["role"] == "user";
                    final bubbleColor =
                        isUser ? theme.colorScheme.primary : theme.cardColor;
                    final textColor =
                        isUser ? Colors.white : theme.colorScheme.onSurface;

                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              msg["text"] ?? "",
                              style: TextStyle(color: textColor, fontSize: 14),
                            ),
                            if (!isUser && msg["model"] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  msg["model"]!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textColor.withOpacity(0.6),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_isTyping) const _TypingIndicator(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        decoration: InputDecoration(
                          hintText: "Savol yoki buyruq yozing...",
                          filled: true,
                          fillColor: theme.cardColor,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "AI yozmoqda",
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final value = _controller.value;
                  int dots = (value * 3).floor() + 1;
                  if (dots > 3) dots = 3;
                  return Text("." * dots,
                      style: const TextStyle(fontSize: 16));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
