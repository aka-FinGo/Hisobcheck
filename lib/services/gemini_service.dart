import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static Future<String?> chat({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userText,
  }) async {
    final uri = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey",
    );

    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "systemInstruction": {
          "parts": [
            {"text": systemPrompt}
          ]
        },
        "contents": [
          {
            "parts": [
              {"text": userText}
            ]
          }
        ]
      }),
    );

    if (res.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    return data["candidates"][0]["content"]["parts"][0]["text"]?.toString();
  }
}

