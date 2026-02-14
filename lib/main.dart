import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // GitHub Actions'dagi --dart-define orqali kelayotgan kalitlar
  const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const String supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  // Agar kalitlar kelsa, Supabase'ni ishga tushiramiz
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aristokrat Mebel',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade900),
        useMaterial3: true,
      ),
      home: Supabase.instance.client.auth.currentUser != null
          ? const HomeScreen()
          : const LoginScreen(),
    );
  }
}
