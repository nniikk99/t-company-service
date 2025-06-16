import 'equipment.dart'; // <-- обязательно!

enum UserRole {
  admin,
  client,
  engineer,
}

class User {
  final String id;
  final String inn;
  final String companyName;
  final String lastName;
  final String firstName;
  final String middleName;
  final String position;
  final String email;
  final String phone;
  final String password;
  final UserRole role;
  final List<String> equipment;

  User({
    required this.id,
    required this.inn,
    required this.companyName,
    required this.lastName,
    required this.firstName,
    required this.middleName,
    required this.position,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
    this.equipment = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      inn: json['inn']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      middleName: json['middle_name']?.toString() ?? '',
      position: json['position']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      role: UserRole.values.firstWhere(
        (role) => role.toString().split('.').last == (json['role'] ?? ''),
        orElse: () => UserRole.client,
      ),
      equipment: (json['equipment'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inn': inn,
      'company_name': companyName,
      'last_name': lastName,
      'first_name': firstName,
      'middle_name': middleName,
      'position': position,
      'email': email,
      'phone': phone,
      'password': password,
      'role': role.toString().split('.').last,
      'equipment': equipment,
    };
  }
}