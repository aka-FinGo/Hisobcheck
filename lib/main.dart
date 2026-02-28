import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'widgets/main_wrapper.dart';
import 'theme/theme_provider.dart';
import 'theme/app_themes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Supabase kalitlari (GitHub Secrets orqali uzatiladi) ──
  const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const String supabaseKey = String.fromEnvironment('SUPABASE_KEY');

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

  // ── ThemeProvider ni yuklash (SharedPreferences dan) ──
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  runApp(
    ChangeNotifierProvider<ThemeProvider>.value(
      value: themeProvider,
      child: const MyApp(),
    ),
  );
}

// ... (importlar o'zgarishsiz qoladi)

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isGlass = themeProvider.currentMode == AppThemeMode.glass;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aristokrat Mebel',
      theme: themeProvider.themeData,
      builder: isGlass ? (context, child) => Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: child,
      ) : null,
      
      // AVTOMATIK LOGIN/LOGOUT MONITORING
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = snapshot.data?.session;
          if (session != null) {
            return const MainWrapper();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
