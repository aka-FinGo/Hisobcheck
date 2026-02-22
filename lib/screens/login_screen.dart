import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Asosiy sahifaga o'tish uchun
import '../widgets/main_wrapper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _supabase = Supabase.instance.client;

  Duration get loginTime => const Duration(milliseconds: 1500);

  // --- 1. LOGIN (KIRISH) ---
  Future<String?> _authUser(LoginData data) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: data.name,
        password: data.password,
      );
      return null;
    } on AuthException catch (e) {
      return 'Xato: ${e.message}'; 
    } catch (e) {
      return 'Tizimda xatolik yuz berdi';
    }
  }

  // --- 2. SIGNUP (RO'YXATDAN O'TISH) ---
  Future<String?> _signupUser(SignupData data) async {
    try {
      // Yangi qo'shilgan "Ism" maydonidan ma'lumotni ajratib olamiz
      final String fullName = data.additionalSignupData?['full_name'] ?? 'Yangi foydalanuvchi';

      // Supabase'ga Email, Parol va Ismni yuboramiz
      await _supabase.auth.signUp(
        email: data.name!,
        password: data.password!,
        data: {'full_name': fullName}, // Bu ma'lumot Supabase metadata'siga saqlanadi
      );
      return null;
    } on AuthException catch (e) {
      return 'Xato: ${e.message}';
    } catch (e) {
      return 'Tizimda xatolik yuz berdi';
    }
  }

  // --- 3. PAROLNI TIKLASH ---
  Future<String?> _recoverPassword(String name) async {
    try {
      await _supabase.auth.resetPasswordForEmail(name);
      return null;
    } on AuthException catch (e) {
      return 'Xato: ${e.message}';
    } catch (e) {
      return 'Tizimda xatolik yuz berdi';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterLogin(
      title: 'ARISTOKRAT', 
      
      theme: LoginTheme(
        primaryColor: const Color(0xFF2E5BFF), 
        accentColor: const Color(0xFF29fd53),  
        buttonTheme: const LoginButtonTheme(
          backgroundColor: Color(0xFF29fd53),
        ),
      ),

      onLogin: _authUser,
      onSignup: _signupUser,
      onRecoverPassword: _recoverPassword,

      // --- RO'YXATDAN O'TISH UCHUN QO'SHIMCHA MAYDONLAR ---
      additionalSignupFields: [
        const UserFormField(
          keyName: 'full_name', // Ma'lumotni ushlab olish uchun kalit so'z
          displayName: 'Ism va Familiya', // Ekranda ko'rinadigan yozuv
          icon: Icon(Icons.person),
        ),
      ],

      // Ilova inglizcha bo'lmasligi uchun yozuvlarni o'zbekchaga o'g'iramiz
      messages: LoginMessages(
        userHint: 'Email yoki Login',
        passwordHint: 'Parol',
        confirmPasswordHint: 'Parolni tasdiqlang',
        loginButton: 'KIRISH',
        signupButton: "RO'YXATDAN O'TISH",
        forgotPasswordButton: 'Parolni unutdingizmi?',
        recoverPasswordButton: 'TIKLASH',
        goBackButton: 'ORQAGA',
        confirmPasswordError: 'Parollar mos kelmadi!',
      ),

      // --- ANIMATSIYA TUGACH, ASOSIY SAHIFAGA O'TISH ---
      onSubmitAnimationCompleted: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainWrapper(),
          ),
        );
      },
    );
  }
}
