import 'package:flutter/material.dart';

class ReloadButton extends StatelessWidget {
  final VoidCallback onPressed; // Funksiyani qabul qilish uchun

  const ReloadButton({
    super.key,
    required this.onPressed, // Majburiy parametr
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: onPressed, // Bosilganda tashqaridan kelgan funksiya ishlaydi
    );
  }
}