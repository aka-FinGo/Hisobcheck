import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'orders_list_screen.dart'; // Yangi sahifani ulash

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // Ma'lumotlar
  List<Map<String, dynamic>> _allClients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  List<Map<String, dynamic>> _orders = [];
  
  // Statistika
  int _totalClients = 0;
  int _newClients = 0;
  int _activeClients = 0;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClients = _allClients.where((client) {
        final name = (client['full_name'] ?? client['name'] ?? "").toString().toLowerCase();
        final phone = (client['phone'] ?? "").toString().toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _supabase.from('clients').select().order('created_at', ascending: false),
        _supabase.from('orders').select('client_id'),
      ]);

      if (!mounted) return;

      final clientsData = List<Map<String, dynamic>>.from(results[0]);
      final ordersData = List<Map<String, dynamic>>.from(results[1]);

      // Statistikani hisoblash
      final now = DateTime.now();
      int newCount = 0;
      
      final activeClientIds = ordersData.map((o) => o['client_id']).toSet();
      int activeCount = clientsData.where((c) => activeClientIds.contains(c['id'])).length;

      for (var c in clientsData) {
        if (c['created_at'] != null) {
          final created = DateTime.parse(c['created_at']);
          if (created.month == now.month && created.year == now.year) {
            newCount++;
          }
        }
      }

      setState(() {
        _allClients = clientsData;
        _filteredClients = clientsData;
        _orders = ordersData;
        
        _totalClients = clientsData.length;
        _newClients = newCount;
        _activeClients = activeCount;
        
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Xato: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- MIJOZ QO'SHISH DIALOGI (Tuzatilgan) ---
  void _showAddClientDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yangi Mijoz Qo'shish"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "F.I.SH *", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefon", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: addressController, decoration: const InputDecoration(labelText: "Manzil", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E5BFF), foregroundColor: Colors.white),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                await _supabase.from('clients').insert({
                  'full_name': nameController.text.trim(),
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'address': addressController.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mijoz qo'shildi!"), backgroundColor: Colors.green));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
              }
            },
            child: const Text("SAQLASH"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text("Mijozlar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh, color: Colors.blue)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. STATISTIKA KARTALARI
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // 1-Qator: Jami va Faol
                      Row(
                        children: [
                          Expanded(child: _buildStatCard("Jami mijozlar", _totalClients.toString(), const Color(0xFF2E5BFF), Icons.people)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildStatCard("Faol mijozlar", _activeClients.toString(), const Color(0xFFFF8C00), Icons.local_fire_department)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // 2-Qator: Yangi va ZAKAZLAR TUGMASI
                      Row(
                        children: [
                          Expanded(child: _buildStatCard("Yangi mijozlar", _newClients.toString(), const Color(0xFF27AE60), Icons.new_releases)),
                          const SizedBox(width: 10),
                          // --- YANGI SARIQ TUGMA ---
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersListScreen()));
                              },
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700), // Sariq rang
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Icon(Icons.folder_special, color: Colors.black54, size: 20),
                                        Icon(Icons.arrow_forward_ios, color: Colors.black54, size: 16),
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                    Text("Barcha Zakazlar", style: TextStyle(color: Colors.black54, fontSize: 12)),
                                    Text("Ro'yxatni ko'rish", style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. QIDIRUV VA TUGMA
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.white,
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Mijozni qidirish...",
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Status: Barcha", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          ElevatedButton.icon(
                            onPressed: _showAddClientDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Yangi Mijoz"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E5BFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 3. JADVAL SARLAVHASI
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: const Row(
                    children: [
                      SizedBox(width: 30, child: Text("#", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      Expanded(flex: 3, child: Text("Mijoz nomi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      Expanded(flex: 2, child: Text("Telefon", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                      Expanded(flex: 2, child: Text("Manzil", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // 4. RO'YXAT
                Expanded(
                  child: _filteredClients.isEmpty
                      ? const Center(child: Text("Mijozlar topilmadi"))
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: _filteredClients.length,
                          separatorBuilder: (ctx, i) => const Divider(height: 1, color: Colors.grey),
                          itemBuilder: (context, index) {
                            final client = _filteredClients[index];
                            final name = client['full_name'] ?? client['name'] ?? "Noma'lum";
                            final phone = client['phone'] ?? "-";
                            final address = client['address'] ?? "-";

                            return Container(
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  SizedBox(width: 30, child: Text("${index + 1}.", style: const TextStyle(fontWeight: FontWeight.bold))),
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Colors.blue.shade100,
                                          child: Text(name.toString().isNotEmpty ? name[0].toUpperCase() : "?", style: const TextStyle(fontSize: 12, color: Colors.blue)),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  ),
                                  Expanded(flex: 2, child: Text(phone, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                                  Expanded(
                                    flex: 2, 
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: address.toString().isNotEmpty ? Colors.green.shade50 : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(5)
                                      ),
                                      child: Text(
                                        address.toString().isNotEmpty ? address : "Manzilsiz",
                                        style: TextStyle(fontSize: 10, color: address.toString().isNotEmpty ? Colors.green : Colors.grey),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // Statistika kartochkasi
  Widget _buildStatCard(String title, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
              const Icon(Icons.more_horiz, color: Colors.white54, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(count, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
