import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'order_details_screen.dart';
import 'admin_approvals.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      setState(() => _isLoading = true);
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);
      
      if (mounted) {
        setState(() {
          _notifications = data;
        });
      }
    } catch (e) {
      debugPrint("Xato (Bildirishnomalar): $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int id, String type, String? targetId) async {
    try {
      // Baza orqali o'qilgan belgisi
      await _supabase.from('notifications').update({'is_read': true}).eq('id', id);
      
      // Mahalliy UI da o'qilgan belgisi (tezkor reaksiya uchun)
      if (mounted) {
        setState(() {
          final idx = _notifications.indexWhere((n) => n['id'] == id);
          if (idx != -1) {
            _notifications[idx]['is_read'] = true;
          }
        });
      }

      // Qaysi turga qarab kerakli oynani ochamiz
      if (!mounted) return;
      if (type == 'withdrawal' || type == 'work_log') {
         Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalsScreen()));
      } else if (type == 'order' && targetId != null) {
         // Agar target_id order ID si bo'lsa (int parse qilib berish qulayroq o'zgaruvchilarga mos)
         final oId = int.tryParse(targetId);
         if (oId != null) {
           Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: oId)));
         }
      }
    } catch (e) {
      debugPrint("Read belgilash xatosi: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGlass = Theme.of(context).scaffoldBackgroundColor == Colors.transparent;
    final bgColor = isGlass ? Colors.transparent : Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Bildirishnomalar", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isGlass ? Colors.transparent : null,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: "Hammasini o'qilgan qilish",
            onPressed: () async {
               final user = _supabase.auth.currentUser;
               if (user != null) {
                 await _supabase.from('notifications').update({'is_read': true}).eq('user_id', user.id).eq('is_read', false);
                 _loadNotifications();
               }
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off, size: 80, color: Colors.grey),
                      SizedBox(height: 15),
                      Text("Bildirishnomalar yo'q", style: TextStyle(color: Colors.grey, fontSize: 18)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isRead = n['is_read'] ?? true;
                      final type = n['type'] ?? 'system';
                      
                      IconData getIcon() {
                        if (type == 'order') return Icons.shopping_bag;
                        if (type == 'withdrawal') return Icons.money_off;
                        if (type == 'work_log') return Icons.fact_check;
                        return Icons.notifications;
                      }

                      Color getIconColor() {
                        if (type == 'order') return Colors.blue;
                        if (type == 'withdrawal') return Colors.orange;
                        if (type == 'work_log') return Colors.green;
                        return Colors.grey;
                      }

                      return InkWell(
                        onTap: () => _markAsRead(n['id'], type, n['target_id']?.toString()),
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isRead 
                              ? (isGlass ? Colors.white.withOpacity(0.05) : Theme.of(context).cardColor)
                              : (isGlass ? Colors.white.withOpacity(0.15) : const Color(0xFFE3F2FD)), // Unread - Light Blue highlight
                            borderRadius: BorderRadius.circular(15),
                            border: isGlass ? Border.all(color: Colors.white24) : null,
                            boxShadow: isGlass ? null : [
                               BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                            ]
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: getIconColor().withOpacity(0.15),
                                child: Icon(getIcon(), color: getIconColor(), size: 24),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n['title'] ?? 'Xabar', 
                                            style: TextStyle(
                                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        if (!isRead)
                                           Container(
                                             width: 10, height: 10,
                                             decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                           )
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    if (n['body'] != null && n['body'].toString().isNotEmpty)
                                      Text(
                                        n['body'],
                                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(n['created_at']).toLocal()),
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
