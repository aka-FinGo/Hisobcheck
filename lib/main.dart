import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart'; // <-- Provider ulandi

import 'screens/login_screen.dart';
import 'widgets/main_wrapper.dart'; 
import 'theme/theme_provider.dart'; // <-- Miyani ulab oldik

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase kalitlari (GitHub Secrets dan o'qiladi)
  const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const String supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  // Supabase'ni ishga tushirish
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );
    } catch (e) {
      debugPrint("Supabase ulanish xatosi: $e");
    }
  }

  runApp(
    // Butun ilovani ThemeProvider bilan o'raymiz!
    ChangeNotifierProvider(
      create: (_) => ThemeProvider()..loadTheme(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Foydalanuvchi tizimga kirganligini aniqlash
    bool isLoggedIn = false;
    try {
      final session = Supabase.instance.client.auth.currentSession;
      isLoggedIn = session != null;
    } catch (_) {
      isLoggedIn = false;
    }

    // ThemeProvider orqali hozirgi mavzuni olamiz
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aristokrat Mebel',
      
      // DIQQAT: Dizayn to'g'ridan-to'g'ri markazdan olinmoqda!
      theme: themeProvider.themeData, 
      
      home: isLoggedIn ? const MainWrapper() : const LoginScreen(),
    );
  }
}
