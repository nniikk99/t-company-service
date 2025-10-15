/// Модель компании
class Company {
  final String id;
  final String name;
  final String? inn;
  final String? address;
  final String? contactEmail;
  final String? contactPhone;
  final String? description;
  final String? orgType; // 'customer' | 'supplier' | 'service_partner'
  final DateTime createdAt;
  final DateTime updatedAt;

  Company({
    required this.id,
    required this.name,
    this.inn,
    this.address,
    this.contactEmail,
    this.contactPhone,
    this.description,
    this.orgType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      inn: json['company_inn'] ?? json['inn'],
      address: json['address'],
      contactEmail: json['contact_email'],
      contactPhone: json['contact_phone'],
      description: json['description'],
      orgType: json['org_type'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (inn != null) 'company_inn': inn,
      if (address != null) 'address': address,
      if (contactEmail != null) 'contact_email': contactEmail,
      if (contactPhone != null) 'contact_phone': contactPhone,
      if (description != null) 'description': description,
      if (orgType != null) 'org_type': orgType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Company copyWith({
    String? id,
    String? name,
    String? inn,
    String? address,
    String? contactEmail,
    String? contactPhone,
    String? description,
    String? orgType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      inn: inn ?? this.inn,
      address: address ?? this.address,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      description: description ?? this.description,
      orgType: orgType ?? this.orgType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Получает тип организации в читаемом виде
  String get orgTypeDisplayName {
    switch (orgType) {
      case 'customer':
        return 'Заказчик';
      case 'supplier':
        return 'Поставщик';
      case 'service_partner':
        return 'Сервисный партнер';
      default:
        return orgType ?? 'Не указан';
    }
  }

  /// Получает иконку для типа организации
  String get orgTypeIcon {
    switch (orgType) {
      case 'customer':
        return '🏢';
      case 'supplier':
        return '📦';
      case 'service_partner':
        return '🔧';
      default:
        return '🏪';
    }
  }

  /// Проверяет, является ли компания заказчиком
  bool get isCustomer => orgType == 'customer';

  /// Проверяет, является ли компания поставщиком
  bool get isSupplier => orgType == 'supplier';

  /// Проверяет, является ли компания сервисным партнером
  bool get isServicePartner => orgType == 'service_partner';
}

