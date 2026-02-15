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
  // --- [ 1. BOSHQARUVCHILAR ] ---
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController(); // Ro'yxatdan o'tish uchun

  bool _isLoading = false;
  bool _isLogin = true;         // Kirish yoki Ro'yxatdan o'tish rejimini belgilaydi
  bool _obscurePassword = true; // Parolni ko'rsatish/yashirish
  bool _rememberMe = false;     // Eslab qolish checkboxi

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials(); // Saqlangan ma'lumotlarni yuklash
  }

  // --- [ 2. ESLAB QOLISH VA YUKLASH ] ---
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

  // --- [ 3. ASOSIY AUTH FUNKSIYASI ] ---
  Future<void> _auth() async {
    if (_email.text.isEmpty || _pass.text.isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      if (_isLogin) {
        // Tizimga kirish (Login)
        await Supabase.instance.client.auth.signInWithPassword(
          email: _email.text.trim(), 
          password: _pass.text.trim(),
        );
      } else {
        // Ro'yxatdan o'tish (Sign Up)
        await Supabase.instance.client.auth.signUp(
          email: _email.text.trim(), 
          password: _pass.text.trim(),
          data: {'full_name': _name.text.trim()}, // Ismni ham saqlaymiz
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ro'yxatdan o'tdingiz! Emailingizni tasdiqlang.")));
        setState(() => _isLogin = true); // Ro'yxatdan o'tgach Login oynasiga qaytaramiz
      }
      
      await _saveCredentials(); // Ma'lumotlarni xotiraga yozish

      if (mounted && _isLogin) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainWrapper()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xatolik: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // --- DAVOMI PASTDA ---
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
              children: [
                // LOGOTIP O'RNIGA IKONKA
                Icon(Icons.house_siding_rounded, size: 80, color: Colors.blue.shade900),
                const SizedBox(height: 10),
                const Text("ARISTOKRAT MEBEL", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 30),

                // ISM KIRITISH (Faqat ro'yxatdan o'tishda chiqadi)
                if (!_isLogin) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: "To'liq ismingiz", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 15),
                ],

                // EMAIL INPUT
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 15),

                // PAROL INPUT (KO'ZCHA BILAN)
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

                // REMEMBER ME VA LOGIN TOGGLE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v!)),
                        const Text("Eslab qolish"),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _isLoading 
                  ? const CircularProgressIndicator() 
                  : ElevatedButton(
                      onPressed: _auth,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                      child: Text(_isLogin ? "KIRISH" : "RO'YXATDAN O'TISH"),
                    ),

                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? "Hisobingiz yo'qmi? Ro'yxatdan o'ting" : "Hisobingiz bormi? Kirish"),
                ),

                const Divider(height: 40),
                
                // TELEGRAM TUGMASI (Placeholder)
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tez kunda Telegram orqali kirish ulanadi!")));
                  },
                  icon: const Icon(Icons.send_rounded, color: Colors.blue),
                  label: const Text("Telegram orqali kirish"),
                  style: OutlinedButton.iconStyleFrom(minimumSize: const Size(double.infinity, 55)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
