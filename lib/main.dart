import 'package:flutter/material.dart';

void main() {
  runApp(const HisobCheckApp());
}

class HisobCheckApp extends StatelessWidget {
  const HisobCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HisobCheck',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 1. O'zgaruvchilar (Inputlar uchun)
  final TextEditingController _birinchiRaqamController = TextEditingController();
  final TextEditingController _ikkinchiRaqamController = TextEditingController();
  
  String _natija = "Natija shu yerda chiqadi";

  // 2. MANTIQ (Funksiya shu yerda yoziladi)
  void _hisoblash() {
    // Matnni raqamga aylantiramiz
    double? raqam1 = double.tryParse(_birinchiRaqamController.text);
    double? raqam2 = double.tryParse(_ikkinchiRaqamController.text);

    if (raqam1 == null || raqam2 == null) {
      setState(() {
        _natija = "Iltimos, to'g'ri raqam kiriting!";
      });
      return;
    }

    // Hozircha oddiy qo'shish amali (Siz istagan formulani shu yerga yozamiz)
    double summa = raqam1 + raqam2;

    // Ekranni yangilash
    setState(() {
      _natija = "Jami: $summa so'm";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("HisobCheck Lite")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Birinchi Input
            TextField(
              controller: _birinchiRaqamController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Birinchi summa",
              ),
            ),
            const SizedBox(height: 20),
            
            // Ikkinchi Input
            TextField(
              controller: _ikkinchiRaqamController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Ikkinchi summa",
              ),
            ),
            const SizedBox(height: 30),

            // Tugma
            ElevatedButton(
              onPressed: _hisoblash,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: const Text("HISOBLASH", style: TextStyle(fontSize: 18)),
            ),
            
            const SizedBox(height: 30),
            
            // Natija
            Text(
              _natija,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
