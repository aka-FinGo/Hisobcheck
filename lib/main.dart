import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'widgets/main_wrapper.dart'; // Navigatsiya hubi

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // GitHub Actions'dan keladigan kalitlar
  const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const String supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aristokrat Mebel',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue.shade900),
      // Seans bo'lsa MainWrapper'ga, bo'lmasa Login'ga
      home: session != null ? const MainWrapper() : const LoginScreen(),
    );
  }
}
