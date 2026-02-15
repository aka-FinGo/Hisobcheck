import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/main_wrapper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- [ 1. BOSHQARUVCHI VA HOLATLAR ] ---
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true; // Parolni yashirish holati
  bool _rememberMe = false;     // Eslab qolish holati

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials(); // Saqlangan ma'lumotlarni yuklash
  }

  // --- [ 2. ESLAB QOLISH MANTIQI ] ---
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _email.text = prefs.getString('saved_email') ?? '';
      _pass.text = prefs.getString('saved_pass') ?? '';
      _rememberMe = prefs.getBool('remember_me') ?? false;
    });
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _email.text.trim());
      await prefs.setString('saved_pass', _pass.text.trim());
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('saved_pass');
      await prefs.setBool('remember_me', false);
    }
  }

  // --- [ 3. KIRISH FUNKSIYASI ] ---
  Future<void> _auth() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(), 
        password: _pass.text.trim(),
      );
      
      await _saveCredentials(); // Muvaffaqiyatli kirsa, ma'lumotlarni saqlash

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainWrapper()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email yoki parol xato!")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person_rounded, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text("Xush kelibsiz!", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),

                // Email Input
                TextField(
                  controller: _email, 
                  decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined))
                ),
                const SizedBox(height: 15),

                // Parol Input (Ko'zcha bilan)
                TextField(
                  controller: _pass,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Parol",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),

                // Eslab qolish Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe, 
                      onChanged: (val) => setState(() => _rememberMe = val!)
                    ),
                    const Text("Eslab qolish"),
                  ],
                ),

                const SizedBox(height: 10),
                _isLoading ? const CircularProgressIndicator() : ElevatedButton(
                  onPressed: _auth, 
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text("TIZIMGA KIRISH")
                ),

                const SizedBox(height: 25),
                const Text("yoki", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 15),

                // --- [ 4. TELEGRAM LOGIN TUGMASI ] ---
                OutlinedButton.icon(
                  onPressed: () { /* Telegram mantiqi keyinroq */ },
                  icon: const Icon(Icons.send_rounded, color: Colors.blue),
                  label: const Text("Telegram orqali kirish"),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 55), side: const BorderSide(color: Colors.blue)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
