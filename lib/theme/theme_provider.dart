import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_themes.dart';

enum AppThemeMode { light, dark, glass }

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _currentMode = AppThemeMode.light;
  
  AppThemeMode get currentMode => _currentMode;

  // Flutter'ning haqiqiy ThemeData'sini qaytaruvchi miya
  ThemeData get themeData {
    switch (_currentMode) {
      case AppThemeMode.dark:
        return AppThemes.darkTheme;
      case AppThemeMode.glass:
        return AppThemes.glassTheme;
      case AppThemeMode.light:
      default:
        return AppThemes.lightTheme;
    }
  }

  void toggleTheme(AppThemeMode mode) async {
    _currentMode = mode;
    notifyListeners(); 
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('theme_mode') ?? 0;
    _currentMode = AppThemeMode.values[savedIndex];
    notifyListeners();
  }
}
