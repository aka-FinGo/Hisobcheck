import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Asosiy Oyna"),
        actions: [
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              // Saytni yangilash kifoya
            },
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: Center(
        child: Text("Xush kelibsiz!\n${user?.email ?? ''}"),
      ),
    );
  }
}
