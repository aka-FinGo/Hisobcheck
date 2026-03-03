import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  static const String _baseUrl =
      "https://api.groq.com/openai/v1/chat/completions";

  static bool _isModelNotFound(http.Response res) {
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

  static Future<http.Response> _call({
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
                "from_date": {"type": "string"},
                "to_date": {"type": "string"}
              },
              "required": ["format", "data_type"]
            }
          }
        }
      ];
    }

    return http.post(
      Uri.parse(_baseUrl),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );
  }

  /// Groq chaqiruvini fallback modellari bilan bajaradi.
  /// `onToolCall` berilsa, function-tool chaqiruvlarini siz tomonda bajaradi.
  static Future<({String? content, http.Response? lastResponse, String usedModel})>
      chatWithFallback({
    required String apiKey,
    required String primaryModel,
    required String systemPrompt,
    required String userText,
    Future<void> Function(Map<String, dynamic> args)? onToolCall,
  }) async {
    final triedModels = <String>[
      primaryModel,
      if (primaryModel.trim() == "groq/compound") "llama-3.3-70b-versatile",
      "llama-3.1-8b-instant",
    ].map((m) => m.trim()).where((m) => m.isNotEmpty).toSet().toList();

    http.Response? lastRes;
    String usedModel = primaryModel;

    for (final mdl in triedModels) {
      usedModel = mdl;
      final res = await _call(
        apiKey: apiKey,
        model: mdl,
        systemPrompt: systemPrompt,
        userText: userText,
      );
      lastRes = res;

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final msg = data["choices"][0]["message"];

        if (msg["tool_calls"] != null && onToolCall != null) {
          final args =
              jsonDecode(msg["tool_calls"][0]["function"]["arguments"]);
          await onToolCall(args as Map<String, dynamic>);
          return (content: null, lastResponse: lastRes, usedModel: usedModel);
        }

        String content = (msg["content"] ?? "").toString();
        if (content.contains("**Answer**")) {
          content = content.split("**Answer**").last.trim();
        }
        return (content: content, lastResponse: lastRes, usedModel: usedModel);
      }

      if (!_isModelNotFound(res)) break;
    }

    return (content: null, lastResponse: lastRes, usedModel: usedModel);
  }
}

