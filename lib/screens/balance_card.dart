// lib/widgets/balance_card.dart
import 'package:flutter/material.dart';

class BalanceCard extends StatelessWidget {
  // Bu vidjet ishlashi uchun kerak bo'lgan ma'lumotlarni so'raymiz
  final double earned;
  final double withdrawn;

  const BalanceCard({
    super.key, 
    required this.earned, 
    required this.withdrawn
  });

  @override
  Widget build(BuildContext context) {
    // O'sha eski dizayn kodi shu yerga keladi
    return Container(
      width: double.infinity, 
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade600]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text("Sof Qoldiq", style: TextStyle(color: Colors.white70)),
          Text("${(earned - withdrawn).toStringAsFixed(0)} so'm", 
               style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
          // ... qolgan qismlar ...
        ],
      ),
    );
  }
}
