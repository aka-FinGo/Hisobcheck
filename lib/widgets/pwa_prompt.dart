import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// MANA SHU YERDA SHARTLI CHAQIRUV ISHLAYDI:
import 'pwa_stub.dart' if (dart.library.html) 'pwa_web.dart';

void checkAndShowPwaPrompt(BuildContext context) {
  if (!kIsWeb) return;

  try {
    // Agar dastur PWA qilib o'rnatilgan bo'lsa, oyna chiqarmaymiz
    if (isStandaloneMode()) return; 
  } catch (e) {
    debugPrint("PWA tekshirishda xato: $e");
  }

  final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isIOS ? Colors.grey.shade100 : Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIOS ? Icons.apple : Icons.android, 
              size: 40, 
              color: isIOS ? Colors.black : Colors.green
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Ilovani telefonga o'rnating!", 
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 15),
          Text(
            isIOS 
              ? "1. Safari brauzerining pastidagi 'Ulashish' (📤) tugmasini bosing.\n\n2. Ro'yxatdan 'Ekranga qo'shish' (Add to Home Screen - ➕) ni tanlang."
              : "Brauzerning o'ng yuqori burchagidagi menyudan (⋮) 'Ilovani o'rnatish' (Install app) tugmasini bosing.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade800, height: 1.5),
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E5BFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("TUSHUNDIM", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          )
        ],
      ),
    )
  );
}
