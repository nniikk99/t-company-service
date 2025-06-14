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
      id: json['id'] as String,
      inn: json['inn'] as String,
      companyName: json['company_name'] as String,
      lastName: json['last_name'] as String,
      firstName: json['first_name'] as String,
      middleName: json['middle_name'] as String,
      position: json['position'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      password: json['password'] as String,
      role: UserRole.values.firstWhere(
        (role) => role.toString().split('.').last == json['role'],
        orElse: () => UserRole.client,
      ),
      equipment: (json['equipment'] as List<dynamic>?)?.cast<String>() ?? [],
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