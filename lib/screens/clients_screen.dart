import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'client_details_screen.dart'; // <--- YANGI FAYLNI ULAYMIZ
import 'orders_list_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // Asl ma'lumotlar
  List<Map<String, dynamic>> _allClients = [];
  List<Map<String, dynamic>> _allOrders = [];
  
  // Ekranda ko'rsatiladigan (Filtrlangan)
  List<Map<String, dynamic>> _displayClients = [];
  
  // Statistika
  int _totalClients = 0;
  int _newClients = 0;
  int _activeClients = 0;

  // Hozirgi tanlangan filtr
  String _currentFilter = 'all'; // 'all', 'active', 'new'

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterData);
  }

  // Ma'lumotlarni yuklash
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _supabase.from('clients').select().order('created_at', ascending: false),
        _supabase.from('orders').select('client_id, status'),
      ]);

      final clients = List<Map<String, dynamic>>.from(results[0]);
      final orders = List<Map<String, dynamic>>.from(results[1]);

      // Statistikani hisoblash
      final now = DateTime.now();
      int newCount = 0;
      final activeClientIds = orders
          .where((o) => o['status'] != 'completed' && o['status'] != 'canceled')
          .map((o) => o['client_id'])
          .toSet();
      
      int activeCount = clients.where((c) => activeClientIds.contains(c['id'])).length;

      for (var c in clients) {
        if (c['created_at'] != null) {
          final created = DateTime.parse(c['created_at']);
          if (created.month == now.month && created.year == now.year) {
            newCount++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _allClients = clients;
          _allOrders = orders;
          _totalClients = clients.length;
          _newClients = newCount;
          _activeClients = activeCount;
          _isLoading = false;
        });
        _filterData(); // Yuklagandan keyin darhol filtrlash
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Filtr va Qidiruv mantig'i
  void _filterData() {
    final query = _searchController.text.toLowerCase();
    
    // 1. Avval kategoriyaga qarab saralaymiz
    List<Map<String, dynamic>> temp = [];
    
    if (_currentFilter == 'active') {
      final activeIds = _allOrders
          .where((o) => o['status'] != 'completed' && o['status'] != 'canceled')
          .map((o) => o['client_id'])
          .toSet();
      temp = _allClients.where((c) => activeIds.contains(c['id'])).toList();
    } else if (_currentFilter == 'new') {
      final now = DateTime.now();
      temp = _allClients.where((c) {
        if (c['created_at'] == null) return false;
        final created = DateTime.parse(c['created_at']);
        return created.month == now.month && created.year == now.year;
      }).toList();
    } else {
      temp = List.from(_allClients); // 'all'
    }

    // 2. Keyin qidiruv so'zi bo'yicha
    if (query.isNotEmpty) {
      temp = temp.where((c) {
        final name = (c['full_name'] ?? c['name'] ?? "").toString().toLowerCase();
        final phone = (c['phone'] ?? "").toString().toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    }

    setState(() {
      _displayClients = temp;
    });
  }

  // Filtrni o'zgartirish funksiyasi
  void _setFilter(String filterType) {
    setState(() {
      _currentFilter = filterType;
    });
    _filterData();
  }

  // Mijoz tafsilotlariga o'tish
  void _openClientDetails(Map<String, dynamic> client) async {
    // await ishlatamiz, chunki u yoqdan qaytganda ma'lumot o'zgargan bo'lishi mumkin
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClientDetailsScreen(client: client)),
    );
    _loadData(); // Qaytib kelganda yangilaymiz
  }

  // Yangi Mijoz Dialogi (O'zgarmagan)
  void _showAddClientDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yangi Mijoz"),
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
                }
              } catch (e) {
                // Xatolikni ko'rsatish
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
        title: const Text("Mijozlar Bazasi", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh, color: Colors.blue)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. STATISTIKA VA FILTR TUGMALARI
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // TUGMA: JAMI
                          Expanded(
                            child: InkWell(
                              onTap: () => _setFilter('all'),
                              child: _buildStatCard(
                                "Jami mijozlar", 
                                _totalClients.toString(), 
                                _currentFilter == 'all' ? const Color(0xFF2E5BFF) : Colors.grey.shade400, 
                                Icons.people
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // TUGMA: FAOL
                          Expanded(
                            child: InkWell(
                              onTap: () => _setFilter('active'),
                              child: _buildStatCard(
                                "Faol mijozlar", 
                                _activeClients.toString(), 
                                _currentFilter == 'active' ? const Color(0xFFFF8C00) : Colors.grey.shade400, 
                                Icons.local_fire_department
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // TUGMA: YANGI
                          Expanded(
                            child: InkWell(
                              onTap: () => _setFilter('new'),
                              child: _buildStatCard(
                                "Yangi mijozlar", 
                                _newClients.toString(), 
                                _currentFilter == 'new' ? const Color(0xFF27AE60) : Colors.grey.shade400, 
                                Icons.new_releases
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersListScreen())),
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.folder_special, color: Colors.black54, size: 20),
                                    SizedBox(height: 10),
                                    Text("Barcha Zakazlar", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                                    Text("Ro'yxat", style: TextStyle(color: Colors.black54, fontSize: 12)),
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

                // 2. QIDIRUV
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Mijozni qidirish...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),

                // 3. QO'SHISH TUGMASI VA HEADER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${_displayClients.length} ta mijoz topildi", style: const TextStyle(color: Colors.grey)),
                      ElevatedButton.icon(
                        onPressed: _showAddClientDialog,
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text("Qo'shish"),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E5BFF), foregroundColor: Colors.white),
                      )
                    ],
                  ),
                ),

                // 4. MUKAMMAL RO'YXAT
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: _displayClients.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final client = _displayClients[index];
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () => _openClientDetails(client), // <--- BOSGANDA ICHIGA KIRISH
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue.shade50,
                                  child: Text(
                                    (client['full_name'] ?? client['name'] ?? "?").toString()[0].toUpperCase(),
                                    style: TextStyle(color: Colors.blue.shade900),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        client['full_name'] ?? client['name'] ?? "Noma'lum",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone, size: 14, color: Colors.grey),
                                          const SizedBox(width: 5),
                                          Text(client['phone'] ?? "-", style: const TextStyle(color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
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
          Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(count, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
