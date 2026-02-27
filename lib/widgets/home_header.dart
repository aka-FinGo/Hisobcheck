import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../screens/user_profile_screen.dart';
import '../screens/notifications_screen.dart';

class HomeHeader extends StatelessWidget {
  final String greeting;
  final String userName;
  final int unreadCount;

  const HomeHeader({
    super.key,
    required this.greeting,
    required this.userName,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text(userName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        Row(
          children: [
            // Bosh sahifadagi bildirishnomalar tugmasi
            Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications_none_rounded, color: Theme.of(context).iconTheme.color, size: 26),
                  onPressed: () {
                    // Navigate to Notifications Screen
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const _DeferredNotificationsScreen()));
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
              ],
            ),
            IconButton(
              icon: Icon(
                themeProvider.currentMode == AppThemeMode.glass 
                  ? Icons.lens_blur_rounded 
                  : (isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                color: Theme.of(context).iconTheme.color,
                size: 26,
              ),
              onPressed: () {
                if (themeProvider.currentMode == AppThemeMode.light) {
                  themeProvider.toggleTheme(AppThemeMode.dark);
                } else if (themeProvider.currentMode == AppThemeMode.dark) {
                  themeProvider.toggleTheme(AppThemeMode.glass);
                } else {
                  themeProvider.toggleTheme(AppThemeMode.light);
                }
              },
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen())),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF2E5BFF).withOpacity(0.15),
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : "A",
                  style: const TextStyle(color: Color(0xFF2E5BFF), fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Buni alohida o'rab qoldirish yaxshi echim (qaramlik sikli aylanmasligi u-n)
class _DeferredNotificationsScreen extends StatelessWidget {
  const _DeferredNotificationsScreen();

  @override
  Widget build(BuildContext context) {
    return const NotificationsScreen();
  }
}
