import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'ai_settings_screen.dart';
import '../services/ai_service.dart';
import '../services/encryption_service.dart';
import '../services/report_generator_service.dart';
import '../services/groq_service.dart';
import '../services/gemini_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, String>> _messages = [];
  final _supabase = Supabase.instance.client;
  bool _isTyping = false;
  String _statusMessage = "";

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<String> _getDbContext({
    required String userId,
    required bool canViewCompanyFinance,
    required bool isSuperAdmin,
    required String roleType,
  }) async {
    try {
      final now = DateTime.now();
      final startOfThisMonth = DateTime(now.year, now.month, 1);
      final startOfLastMonth = DateTime(now.year, now.month - 1, 1);

      Map<String, dynamic> companyFinance = {};
      if (canViewCompanyFinance) {
        final summary = await _supabase.from("ai_erp_summary").select().single();
        final num companyBalanceNum = (summary["total_balance"] ?? 0) as num;
        final num pendingOrdersNum = (summary["pending_orders_count"] ?? 0) as num;
        final num totalItemsNum = (summary["total_items_quantity"] ?? 0) as num;

        final lastMonthOrders = await _supabase
            .from("orders")
            .select("total_price, created_at")
            .gte("created_at", startOfLastMonth.toIso8601String())
            .lt("created_at", startOfThisMonth.toIso8601String());
        
        double lastMonthRevenue = 0;
        for (final o in lastMonthOrders) {
          final num v = (o["total_price"] ?? 0) as num;
          lastMonthRevenue += v.toDouble();
        }

        companyFinance = {
          "balance": companyBalanceNum,
          "pending_orders": pendingOrdersNum.toInt(),
          "stock_items": totalItemsNum.toInt(),
          "last_month_revenue": lastMonthRevenue,
        };
      }

      final works = await _supabase
          .from("work_logs")
          .select("total_sum, created_at")
          .eq("worker_id", userId)
          .eq("is_approved", true);
          
      final withdraws = await _supabase
          .from("withdrawals")
          .select("amount, created_at")
          .eq("worker_id", userId)
          .eq("status", "approved");

      double earned = 0;
      double paid = 0;
      double lastMonthPaid = 0;

      for (final w in works) {
        final num v = (w["total_sum"] ?? 0) as num;
        earned += v.toDouble();
      }
      for (final w in withdraws) {
        final num v = (w["amount"] ?? 0) as num;
        paid += v.toDouble();
        final createdAt = DateTime.tryParse(w["created_at"]?.toString() ?? "");
        if (createdAt != null && !createdAt.isBefore(startOfLastMonth) && createdAt.isBefore(startOfThisMonth)) {
          lastMonthPaid += v.toDouble();
        }
      }

      final personalBalance = earned - paid;

      final ctx = {
        "user": {
          "id": userId,
          "is_super_admin": isSuperAdmin,
          "role_type": roleType,
          "can_view_company_finance": canViewCompanyFinance,
        },
        if (canViewCompanyFinance) "company_finance": companyFinance,
        "personal_finance": {
          "current_balance": personalBalance,
          "total_earned": earned,
          "total_withdrawn": paid,
          "last_month_withdrawn": lastMonthPaid,
        },
      };

      return jsonEncode(ctx);
    } catch (e) {
      return jsonEncode({"error": "context_fetch_failed", "message": e.toString()});
    }
  }

  Future<void> _executeToolCall(Map<String, dynamic> args) async {
    final format = args["format"]?.toString() ?? "pdf";
    final dataType = args["data_type"]?.toString() ?? "finance";

    setState(() {
      _statusMessage = "⚙️ ${dataType.toUpperCase()} bo'yicha $format hisoboti tayyorlanmoqda...";
      _messages.add({"role": "ai", "text": "⚙️ Hisobot tayyorlanmoqda...", "model": "System"});
    });
    
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
      else if (format == "excel") await ReportGeneratorService.generateExcel(data, dataType.toUpperCase(), columns);
      else if (format == "jpg") await ReportGeneratorService.generateImageInfographic({"Jami": "${data.length}"}, dataType.toUpperCase());
      
      setState(() => _statusMessage = "✅ Hisobot tayyor!");
    } catch (e) {
      setState(() => _messages.add({"role": "ai", "text": "❌ Xato: $e", "model": "Error"}));
      setState(() => _statusMessage = "❌ Hisobotda xatolik");
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text, "model": "User"});
      _isTyping = true;
      _statusMessage = "AI o'ylamoqda...";
    });
    _msgCtrl.clear();
    _scrollToBottom();

    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from("profiles")
          .select("*, app_roles(name, role_type, permissions)")
          .eq("id", userId)
          .single();
      
      final bool isSuperAdmin = profile["is_super_admin"] ?? false;
      Map<String, dynamic> customPermissions = Map<String, dynamic>.from(profile["custom_permissions"] ?? {});
      Map<String, dynamic> rolePermissions = {};
      String roleType = "worker";

      if (profile["app_roles"] != null) {
        final ar = Map<String, dynamic>.from(profile["app_roles"]);
        rolePermissions = Map<String, dynamic>.from(ar["permissions"] ?? {});
        roleType = (ar["role_type"] ?? "worker").toString();
      }

      bool hasPermission(String action) {
        if (isSuperAdmin) return true;
        return (customPermissions[action] == true || rolePermissions[action] == true);
      }

      final bool canViewCompanyFinance = hasPermission("can_view_finance");
      final settings = await _supabase.from("app_settings").select("*");
      
      final groqMdl = (settings.firstWhere((s) => s["key"] == "groq_model_name", orElse: () => {"value": "groq/compound"})["value"] ?? "groq/compound").toString();
      final geminiMdl = (settings.firstWhere((s) => s["key"] == "gemini_model_name", orElse: () => {"value": "gemini-2.5-flash"})["value"] ?? "gemini-2.5-flash").toString();
      final globalPrm = (settings.firstWhere((s) => s["key"] == "global_system_prompt", orElse: () => {"value": ""})["value"] ?? "").toString();
      
      final keys = await AiService().getValidAiKeys();
      final groqK = keys["groq"] ?? "";
      final geminiK = keys["gemini"] ?? "";

      final ctxJson = await _getDbContext(
        userId: userId,
        canViewCompanyFinance: canViewCompanyFinance,
        isSuperAdmin: isSuperAdmin,
        roleType: roleType,
      );

      final systemPrompt = """
Siz Aristokrat Mebel ERP yordamchisisiz.
$globalPrm

Foydalanuvchi ruxsatlari va baza holati (JSON):
$ctxJson

Qoidalar:
- Faqat berilgan JSON ma'lumotlariga tayanib javob bering.
- Agar foydalanuvchida ruxsat bo'lmasa ("can_view_company_finance": false), kompaniya moliyasi haqida "Sizda bu ma'lumotni ko'rish huquqi yo'q" deb javob bering.
- "Reasoning" yoki ichki tahlilingizni ko'rsatmang. Faqat yakuniy javobni o'zbek tilida bering.
""";

      if (groqK.isNotEmpty) {
        setState(() => _statusMessage = "Groq orqali ulanmoqda...");
        final result = await GroqService.chatWithFallback(
          apiKey: groqK,
          primaryModel: groqMdl,
          systemPrompt: systemPrompt,
          userText: text,
          onToolCall: _executeToolCall,
        );

        if (result.content != null) {
          setState(() => _messages.add({"role": "ai", "text": result.content!, "model": "⚡ ${result.usedModel}"}));
          setState(() => _statusMessage = "Tayyor");
          _scrollToBottom();
          return;
        } else if (result.lastResponse?.statusCode != 200 && geminiK.isEmpty) {
          throw Exception("Groq xatosi: ${result.lastResponse?.body}");
        }
      }

      if (geminiK.isNotEmpty) {
        setState(() => _statusMessage = "Gemini orqali ulanmoqda...");
        final geminiRes = await GeminiService.chat(
          apiKey: geminiK,
          model: geminiMdl,
          systemPrompt: systemPrompt,
          userText: text,
        );

        if (geminiRes != null) {
          setState(() => _messages.add({"role": "ai", "text": geminiRes, "model": "✨ $geminiMdl"}));
          setState(() => _statusMessage = "Tayyor");
        } else {
          throw Exception("Gemini xatosi yuz berdi");
        }
      } else if (groqK.isEmpty) {
        throw Exception("API kalitlari topilmadi. Sozlamalarni tekshiring.");
      }

    } catch (e) {
      setState(() {
        _messages.add({"role": "ai", "text": "Xato: $e", "model": "Error"});
        _statusMessage = "Xato yuz berdi";
      });
    } finally {
      if (mounted) setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Aristokrat AI", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_statusMessage.isNotEmpty)
              Text(
                _statusMessage,
                style: TextStyle(fontSize: 11, color: theme.colorScheme.primary.withOpacity(0.8), fontWeight: FontWeight.w400),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => setState(() => _messages.clear()),
            tooltip: "Chatni tozalash",
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // Dynamic status notification at the top
          if (_isTyping)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: theme.colorScheme.primary.withOpacity(0.1),
              child: const Center(
                child: Text(
                  "AI yozmoqda...",
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["role"] == "user";
                return _buildMessageBubble(msg, isUser, theme);
              },
            ),
          ),

          // Message Input Field (Fintech style)
          _buildInputArea(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, String> msg, bool isUser, ThemeData theme) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser 
              ? theme.colorScheme.primary 
              : (theme.brightness == Brightness.dark ? Colors.grey[900] : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg["text"] ?? "",
              style: TextStyle(
                color: isUser ? Colors.white : theme.textTheme.bodyLarge?.color,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (!isUser && msg["model"] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  msg["model"]!,
                  style: TextStyle(
                    fontSize: 10,
                    color: (theme.textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
                ),
              ),
              child: TextField(
                controller: _msgCtrl,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: "Savol yozing...",
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
