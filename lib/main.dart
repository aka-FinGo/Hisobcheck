import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Bu yerga o'z URL va KEYlaringizni yozing
const supabaseUrl = 'SU_SIZNING_SUPABASE_URL';
const supabaseKey = 'SU_SIZNING_ANON_KEY';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Supabasega ulanish
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moliyachi',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // Hozircha bo'sh ekran ko'rsatib turamiz
      home: const Scaffold(
        body: Center(child: Text("Supabasega ulandi!")),
      ),
    );
  }
}
