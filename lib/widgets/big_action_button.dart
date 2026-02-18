import 'package:flutter/material.dart';

class BigActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final IconData icon;

  const BigActionButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = const Color(0xFF2E5BFF),
    this.icon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          text.toUpperCase(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: color.withOpacity(0.4),
        ),
      ),
    );
  }
}
