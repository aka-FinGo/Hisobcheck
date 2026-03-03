import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirmPass = TextEditingController();
  final _name = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _confirmPass.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = _email.text.trim();
    final pass = _pass.text.trim();
    final confirm = _confirmPass.text.trim();
    final name = _name.text.trim();

    if (email.isEmpty || pass.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Barcha maydonlarni to'ldiring!")),
      );
      return;
    }

    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Parollar mos kelmadi!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: pass,
        data: {'full_name': name},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Muvaffaqiyatli ro'yxatdan o'tdingiz! Emailingizni tasdiqlang.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Ushbu xizmat tez orada ishga tushadi")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF5EB4A8),
              Color(0xFF2E5B55),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: size.height * 0.12),
              const Padding(
                padding: EdgeInsets.only(left: 40),
                child: Text(
                  "Ro'yxatdan o'tish",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(height: size.height * 0.05),
              Container(
                width: double.infinity,
                constraints: BoxConstraints(minHeight: size.height * 0.83),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1FAF8),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(60),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputField(
                      label: "Ism",
                      hint: "To'liq ismingizni kiriting",
                      controller: _name,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: "Email",
                      hint: "Email manzilingizni kiriting",
                      controller: _email,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: "Parol",
                      hint: "Parol yarating",
                      controller: _pass,
                      isPassword: true,
                      obscure: _obscurePassword,
                      onObscureChanged: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: "Parolni tasdiqlash",
                      hint: "Parolni qayta kiriting",
                      controller: _confirmPass,
                      isPassword: true,
                      obscure: _obscureConfirmPassword,
                      onObscureChanged: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E5B55)))
                        : ElevatedButton(
                            onPressed: _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E5B55),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 0,
                            ),
                            child: const Text("Ro'yxatdan o'tish", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Colors.black12)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text("yoki", style: TextStyle(color: Colors.black26, fontSize: 12)),
                        ),
                        const Expanded(child: Divider(color: Colors.black12)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialIcon(Icons.g_mobiledata, _showComingSoon),
                        const SizedBox(width: 30),
                        _buildSocialIcon(Icons.apple, _showComingSoon),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Hisobingiz bormi? Kirish",
                          style: TextStyle(color: Color(0xFF2E5B55), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onObscureChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF2E5B55),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.black.withOpacity(0.3), fontSize: 13),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black12, width: 1),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2E5B55), width: 2),
            ),
            suffixIcon: isPassword 
              ? IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF2E5B55), size: 18),
                  onPressed: onObscureChanged,
                ) 
              : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 28,
          color: const Color(0xFF2E5B55),
        ),
      ),
    );
  }
}
