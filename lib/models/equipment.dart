class Equipment {
  final String id;
  final String title;
  final String description;
  final String serialNumber;
  final String userId;
  final DateTime createdAt;
  final DateTime? lastServiceDate;
  final String address;
  final String contactName;
  final String contactPhone;
  final String? contactEmail;

  Equipment({
    required this.id,
    required this.title,
    required this.description,
    required this.serialNumber,
    required this.userId,
    required this.createdAt,
    this.lastServiceDate,
    required this.address,
    required this.contactName,
    required this.contactPhone,
    this.contactEmail,
  });

  Equipment copyWith({
    String? title,
    String? description,
    String? serialNumber,
    String? userId,
    DateTime? createdAt,
    DateTime? lastServiceDate,
    String? address,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
  }) {
    return Equipment(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      serialNumber: serialNumber ?? this.serialNumber,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      address: address ?? this.address,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
    );
  }

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      serialNumber: json['serial_number'] as String,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastServiceDate: json['last_service_date'] != null
          ? DateTime.parse(json['last_service_date'] as String)
          : null,
      address: json['address'] ?? '',
      contactName: json['contact_name'] ?? '',
      contactPhone: json['contact_phone'] ?? '',
      contactEmail: json['contact_email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'serial_number': serialNumber,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'last_service_date': lastServiceDate?.toIso8601String(),
      'address': address,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
    };
  }
}