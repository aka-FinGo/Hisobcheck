class UserModel {
  final String id;
  final String fullName;
  final String role; // 'admin', 'boss', 'worker'
  final double balance; // Hozirgi qarzdorlik
  final String phone;

  UserModel({
    required this.id,
    required this.fullName,
    required this.role,
    required this.balance,
    required this.phone,
  });

  // 1. Bazadan (JSON) kelgan ma'lumotni Dartga o'girish
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? 'Nomsiz',
      role: json['role'] ?? 'worker',
      // Raqamlar ba'zan 'int', ba'zan 'double' kelishi mumkin, shuning uchun ehtiyot bo'lamiz
      balance: (json['balance'] ?? 0).toDouble(),
      phone: json['phone'] ?? '',
    );
  }

  // 2. Dartdan Bazaga (JSON) yuborish
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role,
      'balance': balance,
      'phone': phone,
    };
  }
}
