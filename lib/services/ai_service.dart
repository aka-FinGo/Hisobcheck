import 'package:supabase_flutter/supabase_flutter.dart';
import 'encryption_service.dart';

class AiService {
  final _supabase = Supabase.instance.client;

  // GitHub Environment'dan keladigan asosiy (Admin) kalitlar
  static const String defaultGroqKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const String defaultGeminiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  Future<Map<String, String>> getValidAiKeys() async {
    final userId = _supabase.auth.currentUser!.id;

    // 1. Foydalanuvchining o'z shaxsiy kalitini qidiramiz
    final profile = await _supabase.from('profiles').select('groq_api_key, gemini_api_key').eq('id', userId).single();
    
    final userGroq = EncryptionService.decryptText(profile['groq_api_key'] ?? '');
    final userGemini = EncryptionService.decryptText(profile['gemini_api_key'] ?? '');

    if (userGroq.isNotEmpty || userGemini.isNotEmpty) {
      return {'groq': userGroq, 'gemini': userGemini, 'source': 'personal'};
    }

    // 2. Agar foydalanuvchida kalit bo'lmasa, Admin ruxsat berganmi yo'qmi tekshiramiz
    final setting = await _supabase.from('app_settings').select('value').eq('key', 'allow_default_ai').maybeSingle();
    final bool allowDefault = setting != null && setting['value'] == 'true';

    if (allowDefault) {
      if (defaultGroqKey.isEmpty && defaultGeminiKey.isEmpty) {
        throw Exception("Admin tizimi xatosi: Default API kalitlar Github'da topilmadi.");
      }
      return {'groq': defaultGroqKey, 'gemini': defaultGeminiKey, 'source': 'admin'};
    }

    // 3. Ikkisi ham bo'lmasa, demak AI dan foydalanib bo'lmaydi
    throw Exception("TUTORIAL_NEEDED"); 
  }
}
