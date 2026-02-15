import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/main_wrapper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;

  Future<void> _auth() async {
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _email.text.trim(), password: _pass.text.trim(),
        );
      } else {
        await Supabase.instance.client.auth.signUp(
          email: _email.text.trim(), password: _pass.text.trim(),
          data: {'full_name': _name.text.trim()},
        );
        if (mounted) setState(() => _isLogin = true);
      }
      if (mounted && _isLogin) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainWrapper()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Xatolik yuz berdi!")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_isLogin ? "Kirish" : "Ro'yxatdan o'tish", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              if (!_isLogin) TextField(controller: _name, decoration: const InputDecoration(labelText: "Ism Familiya", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _email, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _pass, decoration: const InputDecoration(labelText: "Parol", border: OutlineInputBorder()), obscureText: true),
              const SizedBox(height: 20),
              _isLoading ? const CircularProgressIndicator() : ElevatedButton(
                onPressed: _auth, 
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: Text(_isLogin ? "KIRISH" : "RO'YXATDAN O'TISH")
              ),
              TextButton(onPressed: () => setState(() => _isLogin = !_isLogin), child: Text(_isLogin ? "Hisobingiz yo'qmi? Ochish" : "Hisobingiz bormi? Kirish"))
            ],
          ),
        ),
      ),
    );
  }
}
