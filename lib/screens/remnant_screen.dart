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
  List<dynamic> _filteredRemnants = []; // Qidiruv uchun
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRemnants();
  }

  // Bazadan qoldiqlarni yuklash
  Future<void> _loadRemnants() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('remnants')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _remnants = data;
        _filteredRemnants = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showMsg("Xatolik: $e");
    }
  }

  // Qidiruv mantiqi (Rangiga qarab)
  void _filterRemnants(String query) {
    setState(() {
      _filteredRemnants = _remnants
          .where((r) => r['color_name'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- 2-QISM DAVOM ETADI (Pastdagi xabarda) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("LDSP Qoldiqlari")),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRemnantDialog,
        backgroundColor: Colors.blue.shade900,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Qidiruv paneli
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterRemnants,
              decoration: InputDecoration(
                hintText: "Rang bo'yicha qidirish...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRemnants.isEmpty
                    ? const Center(child: Text("Qoldiqlar topilmadi"))
                    : ListView.builder(
                        itemCount: _filteredRemnants.length,
                        itemBuilder: (context, index) {
                          final item = _filteredRemnants[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            child: ListTile(
                              leading: Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(5)),
                                child: const Icon(Icons.layers, color: Colors.brown),
                              ),
                              title: Text("${item['color_name']} (${item['thickness']})", style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("O'lcham: ${item['width']} x ${item['height']} mm\nJoyi: ${item['location'] ?? 'Noma'lum'}"),
                              trailing: CircleAvatar(
                                radius: 15,
                                child: Text("${item['quantity']}"),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // Yangi qoldiq qo'shish dialogi
  void _showAddRemnantDialog() {
    final colorCtrl = TextEditingController();
    final widthCtrl = TextEditingController();
    final heightCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: "1");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yangi Qoldiq"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: colorCtrl, decoration: const InputDecoration(labelText: "Rangi (masalan: Oq)")),
              TextField(controller: widthCtrl, decoration: const InputDecoration(labelText: "Eni (mm)"), keyboardType: TextInputType.number),
              TextField(controller: heightCtrl, decoration: const InputDecoration(labelText: "Bo'yi (mm)"), keyboardType: TextInputType.number),
              TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: "Soni"), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bekor qilish")),
          ElevatedButton(
            onPressed: () async {
              if (colorCtrl.text.isEmpty || widthCtrl.text.isEmpty || heightCtrl.text.isEmpty) return;
              await _supabase.from('remnants').insert({
                'color_name': colorCtrl.text,
                'width': double.parse(widthCtrl.text),
                'height': double.parse(heightCtrl.text),
                'quantity': int.parse(qtyCtrl.text),
              });
              Navigator.pop(context);
              _loadRemnants();
            },
            child: const Text("SAQLASH"),
          ),
        ],
      ),
    );
  }
} // Klas oxiri
