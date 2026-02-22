import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Sozlamani xotirada saqlash uchun

// Mavzu turlari
enum AppThemeMode { light, dark, glass }

class ThemeProvider extends ChangeNotifier {
  // Boshlanishiga standart (light) rejim
  AppThemeMode _currentMode = AppThemeMode.light;
  
  AppThemeMode get currentMode => _currentMode;

  // Mavzuni o'zgartirish va xotiraga saqlash
  void toggleTheme(AppThemeMode mode) async {
    _currentMode = mode;
    notifyListeners(); // Butun ilovaga "Mavzu o'zgardi!" deb xabar beradi
    
    // Xotiraga yozib qo'yamiz, keyingi safar kirganda eslab qoladi
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('theme_mode', mode.index);
  }

  // Ilova ochilganda oxirgi tanlangan mavzuni yuklash
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedModeIndex = prefs.getInt('theme_mode') ?? 0;
    _currentMode = AppThemeMode.values[savedModeIndex];
    notifyListeners();
  }
  
  // --- MAVZUGA QARAB RANGLARNI OLISH UCHUN YORDAMCHI ---
  
  // Oyna effekti uchun shaffof rang
  Color get glassColor => _currentMode == AppThemeMode.glass 
      ? Colors.white.withOpacity(0.2) 
      : (_currentMode == AppThemeMode.dark ? const Color(0xFF1E1E2C) : Colors.white);

  // Matn rangi
  Color get textColor => _currentMode == AppThemeMode.light ? Colors.black : Colors.white;
  
  // Fon rangi (faqat light va dark uchun)
  Color get backgroundColor => _currentMode == AppThemeMode.dark 
      ? const Color(0xFF121212) 
      : const Color(0xFFF8F9FE);
}
