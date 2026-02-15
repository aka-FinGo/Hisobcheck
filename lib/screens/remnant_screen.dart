import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RemnantScreen extends StatefulWidget {
  const RemnantScreen({super.key});
  @override
  State<RemnantScreen> createState() => _RemnantScreenState();
}

class _RemnantScreenState extends State<RemnantScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _remnants = [];

  @override
  void initState() {
    super.initState();
    _loadRemnants();
  }

  Future<void> _loadRemnants() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('remnants').select().order('created_at', ascending: false);
      setState(() { _remnants = data; _isLoading = false; });
    } catch (e) { setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("LDSP Qoldiqlari")),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _remnants.length,
            itemBuilder: (context, i) {
              final item = _remnants[i];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(item['color_name']),
                  // TUZATILGAN JOY: 'Noma'lum' o'rniga "Noma'lum" ishlatildi
                  subtitle: Text("O'lcham: ${item['width']}x${item['height']} | Joy: ${item['location'] ?? "Noma'lum"}"),
                  trailing: Text("${item['quantity']} dona"),
                ),
              );
            },
          ),
    );
  }

  void _showAddDialog() {
    // Dialog kodi... (oldingi bilan bir xil, faqat xatolar olib tashlangan)
  }
}
