class Site {
  final String id;
  final String? companyId;
  final String? companyInn; // Добавляем ИНН компании
  final String name;
  final String? region;
  final String address;
  final String? contactPersonId;
  final String? phone;
  final String? email;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Site({
    required this.id,
    this.companyId,
    this.companyInn,
    required this.name,
    this.region,
    required this.address,
    this.contactPersonId,
    this.phone,
    this.email,
    required this.createdAt,
    this.updatedAt,
  });

  factory Site.fromJson(Map<String, dynamic> json) {
    return Site(
      id: json['id'],
      companyId: json['company_id'],
      companyInn: json['company_inn'],
      name: json['name'],
      region: json['region'],
      address: json['address'] ?? '',
      contactPersonId: json['contact_person_id'],
      phone: json['phone'],
      email: json['email'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'company_inn': companyInn,
      'name': name,
      'region': region,
      'address': address,
      'contact_person_id': contactPersonId,
      'phone': phone,
      'email': email,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Site copyWith({
    String? id,
    String? companyId,
    String? companyInn,
    String? name,
    String? region,
    String? address,
    String? contactPersonId,
    String? phone,
    String? email,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Site(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      companyInn: companyInn ?? this.companyInn,
      name: name ?? this.name,
      region: region ?? this.region,
      address: address ?? this.address,
      contactPersonId: contactPersonId ?? this.contactPersonId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
