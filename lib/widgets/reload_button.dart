// lib/widgets/reload_button.dart

import 'package:flutter/material.dart';

class ReloadButton extends StatelessWidget {
  final Future<void> Function() onRefresh; // Qaysi funksiyani ishlatish kerakligi
  final Color color; // Rangini o'zgartirish imkoniyati (oq yoki qora)

  const ReloadButton({
    super.key, 
    required this.onRefresh,
    this.color = Colors.white, // Default rangi oq
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: "Ma'lumotlarni yangilash",
      icon: Icon(Icons.refresh, color: color),
      onPressed: () async {
        // 1. Xabar chiqaramiz
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ma'lumotlar yangilanmoqda..."), 
            duration: Duration(milliseconds: 800),
            backgroundColor: Colors.blue,
          ),
        );

        // 2. Biz bergan funksiyani ishga tushiramiz
        await onRefresh();
      },
    );
  }
}