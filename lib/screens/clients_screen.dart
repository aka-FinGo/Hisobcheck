import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'client_details_screen.dart'; // Mijoz ichiga kirish
import 'orders_list_screen.dart';    // Zakazlar ro'yxati

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  // --- KEYINGI ZAKAZ RAQAMINI HISOBLASH ---
  Future<String> _calculateNextOrderNumber() async {
    try {
      // 1. Bazadan eng oxirgi yaratilgan zakazni olamiz
      final response = await _supabase
          .from('orders')
          .select('order_number')
          .order('created_at', ascending: false) // Eng yangisi birinchi
          .limit(1)
          .maybeSingle();

      String currentMonth = DateTime.now().month.toString().padLeft(2, '0'); // Masalan: "02"
      int nextSeq = 100; // Agar baza bo'm-bo'sh bo'lsa, 100 dan boshlaymiz

      if (response != null && response['order_number'] != null) {
        String lastOrderStr = response['order_number'].toString();
        // Formatimiz: "100_02_Ali_Oshxona" yoki "100_02"
        // Biz "_" belgisiga qarab bo'laklaymiz
        List<String> parts = lastOrderStr.split('_');

        if (parts.isNotEmpty) {
          // Birinchi bo'lakni (masalan "100") son qilib olamiz
          int? lastSeq = int.tryParse(parts[0]);
          if (lastSeq != null) {
            nextSeq = lastSeq + 1; // 1 qo'shamiz -> 101
          }
        }
      }

      return "${nextSeq}_$currentMonth"; // Natija: "101_02"
    } catch (e) {
      debugPrint("Raqam hisoblashda xato: $e");
      return "100_${DateTime.now().month.toString().padLeft(2, '0')}";
    }
  }
  // Ma'lumotlar
  List<Map<String, dynamic>> _allClients = [];
  List<Map<String, dynamic>> _displayClients = []; // Ekranda ko'rinadigan
  List<Map<String, dynamic>> _allOrders = [];
  
  // Statistika
  int _totalClients = 0;
  int _newClients = 0;
  int _activeClients = 0;

  // Filtr
  String _currentFilter = 'all'; // 'all', 'active', 'new'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterData);
  }

  // --- MA'LUMOT YUKLASH ---
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
        _filterData(); 
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FILTRLASH ---
  void _filterData() {
    final query = _searchController.text.toLowerCase();
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
      temp = List.from(_allClients);
    }

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

  void _setFilter(String filterType) {
    setState(() => _currentFilter = filterType);
    _filterData();
  }

  // --- ZAKAZ (LOYIHA) QO'SHISH DIALOGI ---
  void _showAddOrderDialog() {
    dynamic selectedClientId; 
    final projectController = TextEditingController();
    final areaController = TextEditingController();
    final priceController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: Text("Yangi Loyiha Ochish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              const SizedBox(height: 20),
              
              // 1. MIJOZNI TANLASH
              DropdownButtonFormField<dynamic>(
                decoration: const InputDecoration(
                  labelText: "Mijozni tanlang", 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person)
                ),
                items: _allClients.map((c) => DropdownMenuItem<dynamic>(
                  value: c['id'], 
                  child: Text(c['full_name'] ?? c['name'] ?? "Noma'lum", overflow: TextOverflow.ellipsis)
                )).toList(),
                onChanged: (v) => setModalState(() => selectedClientId = v),
              ),
              const SizedBox(height: 12),

              // 2. LOYIHA NOMI
              TextField(
                controller: projectController, 
                decoration: const InputDecoration(labelText: "Loyiha nomi (Msl: Oshxona)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.kitchen))
              ),
              const SizedBox(height: 12),

              // 3. KVADRAT VA NARX
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: areaController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "Hajm (m²)", border: OutlineInputBorder(), suffixText: "m²"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Summa", border: OutlineInputBorder(), suffixText: "so'm"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. IZOH
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Qo'shimcha ma'lumot (Ixtiyoriy)", 
                  hintText: "Msl: Fasad oq MDF, shoshilinch...",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_alt_outlined)
                ),
              ),
              const SizedBox(height: 20),

              // 5. SAQLASH TUGMASI
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedClientId == null || projectController.text.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mijoz va Loyiha nomi majburiy!")));
                       return;
                    }

                    final client = _allClients.firstWhere((c) => c['id'] == selectedClientId);
                    String clientSafeName = (client['full_name'] ?? client['name']).toString().replaceAll(' ', '-');

                    // Avtomatik ID: 100_01_Mijoz_Loyiha
                    String prefix = "100";
                    String seq = (_allOrders.length + 1).toString().padLeft(2, '0');
                    String generatedName = "${prefix}_${seq}_${clientSafeName}_${projectController.text.replaceAll(' ', '-')}";

                    double area = double.tryParse(areaController.text.replaceAll(',', '.')) ?? 0;

                    try {
                      await _supabase.from('orders').insert({
                        'client_id': selectedClientId, 
                        'project_name': generatedName,
                        'order_number': generatedName,
                        'total_area_m2': area,       
                        'measured_area': area,      
                        'total_price': double.tryParse(priceController.text) ?? 0,
                        'notes': notesController.text,
                        'status': 'pending', 
                      });

                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loyiha yaratildi!"), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      debugPrint("Order xato: $e");
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                  child: const Text("ZAKAZNI YARATISH"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- YANGI MIJOZ DIALOGI ---
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
              } catch (e) { }
            },
            child: const Text("SAQLASH"),
          ),
        ],
      ),
    );
  }

  // --- MIJOZ TAFSILOTLARIGA O'TISH ---
  void _openClientDetails(Map<String, dynamic> client) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClientDetailsScreen(client: client)),
    );
    _loadData();
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
      
      // --- TUGMA: YANGI ZAKAZ QO'SHISH ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOrderDialog,
        backgroundColor: const Color(0xFFFFD700), // Sariq rang
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_task),
        label: const Text("YANGI ZAKAZ"),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. STATISTIKA
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: InkWell(onTap: () => _setFilter('all'), child: _buildStatCard("Jami mijozlar", _totalClients.toString(), _currentFilter == 'all' ? const Color(0xFF2E5BFF) : Colors.grey.shade400, Icons.people))),
                          const SizedBox(width: 10),
                          Expanded(child: InkWell(onTap: () => _setFilter('active'), child: _buildStatCard("Faol mijozlar", _activeClients.toString(), _currentFilter == 'active' ? const Color(0xFFFF8C00) : Colors.grey.shade400, Icons.local_fire_department))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: InkWell(onTap: () => _setFilter('new'), child: _buildStatCard("Yangi mijozlar", _newClients.toString(), _currentFilter == 'new' ? const Color(0xFF27AE60) : Colors.grey.shade400, Icons.new_releases))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersListScreen())),
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.list_alt, color: Colors.blue, size: 20),
                                    SizedBox(height: 10),
                                    Text("Barcha Zakazlar", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                    Text("Ro'yxatni ko'rish", style: TextStyle(color: Colors.grey, fontSize: 10)),
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

                // 3. QO'SHISH TUGMASI (MIJOZ)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${_displayClients.length} ta mijoz topildi", style: const TextStyle(color: Colors.grey)),
                      ElevatedButton.icon(
                        onPressed: _showAddClientDialog,
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text("Yangi Mijoz"),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E5BFF), foregroundColor: Colors.white),
                      )
                    ],
                  ),
                ),

                // 4. RO'YXAT
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
                          onTap: () => _openClientDetails(client),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue.shade50,
                                  child: Text((client['full_name'] ?? client['name'] ?? "?").toString()[0].toUpperCase(), style: TextStyle(color: Colors.blue.shade900)),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(client['full_name'] ?? client['name'] ?? "Noma'lum", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text(client['phone'] ?? "-", style: const TextStyle(color: Colors.grey)),
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
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
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
