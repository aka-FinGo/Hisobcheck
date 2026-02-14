import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Asosiy Sahifa"),
        actions: [
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              // Brauzerni qayta yuklash orqali Login'ga qaytamiz
            }, 
            icon: const Icon(Icons.logout)
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            Text("Xush kelibsiz!\n${user?.email}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}
