import 'equipment.dart'; // <-- обязательно!

class User {
  final String inn;
  final String companyName;
  final String password;
  final List<Equipment> equipment;

  User({
    required this.inn,
    required this.companyName,
    required this.password,
    required this.equipment,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      inn: json['inn'] ?? '',
      companyName: json['companyName'] ?? '',
      password: json['password'] ?? '',
      equipment: (json['equipment'] as List<dynamic>? ?? [])
          .map((e) => Equipment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'inn': inn,
    'companyName': companyName,
    'password': password,
    'equipment': equipment.map((e) => e.toJson()).toList(),
  };
}