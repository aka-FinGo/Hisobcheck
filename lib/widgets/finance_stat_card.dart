import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FinanceStatCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  final bool isExpense;

  const FinanceStatCard({
    super.key,
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
    this.isExpense = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat("#,###");
    String formattedAmount = formatter.format(amount).replaceAll(',', ' ');

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              "$formattedAmount", 
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              "so'm",
              style: TextStyle(color: Colors.white50, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
