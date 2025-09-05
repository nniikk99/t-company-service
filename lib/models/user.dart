enum UserRole {
  admin,
  clientManager,
  clientResponsible,
}

class User {
  final String id;
  final String telegramId;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? email;
  final UserRole role;
  final String? clientId;
  final bool consentToPersonalData;
  final DateTime createdAt;

  User({
    required this.id,
    required this.telegramId,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.email,
    required this.role,
    this.clientId,
    required this.consentToPersonalData,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      telegramId: json['telegram_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      phone: json['phone'],
      email: json['email'],
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${json['role']}',
        orElse: () => UserRole.clientManager,
      ),
      clientId: json['client_id'],
      consentToPersonalData: json['consent_to_personal_data'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'telegram_id': telegramId,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'email': email,
      'role': role.toString().split('.').last,
      'client_id': clientId,
      'consent_to_personal_data': consentToPersonalData,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
