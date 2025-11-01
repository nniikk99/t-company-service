enum EquipmentStatus {
  active,       // Активно
  maintenance,  // На обслуживании
  inactive,     // Неактивно
  broken,       // Неисправно
}

class Equipment {
  final String id;
  final String? clientId;              // Для обратной совместимости
  final String? companyId;             // Новое поле для Supabase
  final String? companyInn;            // ИНН компании
  final String? supplierId;            // ID поставщика, который поставил оборудование
  final String name;                   // Название оборудования
  final String manufacturer;          // Производитель
  final String model;                  // Модель
  final String? modification;         // Модификация
  final String? serialNumber;         // Серийный номер
  final String? siteId;               // ID площадки
  final String location;              // Название площадки (для обратной совместимости)
  final String address;               // Адрес площадки (для обратной совместимости)
  final EquipmentStatus status;
  final String? responsibleUserId;    // Ответственное контактное лицо
  final String? description;          // Описание
  final String? imageUrl;             // URL изображения
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? installationDate;   // Дата установки
  final DateTime? lastServiceDate;    // Дата последнего обслуживания
  final DateTime? nextServiceDate;    // Дата следующего обслуживания
  final Map<String, dynamic>? specifications; // Технические характеристики
  final List<String>? manuals;        // Инструкции/мануалы
  final List<String>? photos;         // Фотографии оборудования

  Equipment({
    required this.id,
    this.clientId,
    this.companyId,
    this.companyInn,
    this.supplierId,
    required this.name,
    required this.manufacturer,
    required this.model,
    this.modification,
    this.serialNumber,
    this.siteId,
    required this.location,
    required this.address,
    required this.status,
    this.responsibleUserId,
    this.description,
    this.imageUrl,
    required this.createdAt,
    this.updatedAt,
    this.installationDate,
    this.lastServiceDate,
    this.nextServiceDate,
    this.specifications,
    this.manuals,
    this.photos,
  });

  // Геттеры для удобства
  String get statusDisplayName {
    switch (status) {
      case EquipmentStatus.active:
        return 'Активно';
      case EquipmentStatus.maintenance:
        return 'На обслуживании';
      case EquipmentStatus.inactive:
        return 'Неактивно';
      case EquipmentStatus.broken:
        return 'Неисправно';
    }
  }

  String get fullTitle => '$manufacturer $model';
  String get displayName => modification != null ? '$manufacturer $model ($modification)' : '$manufacturer $model';
  
  bool get needsService {
    if (nextServiceDate == null) return false;
    return DateTime.now().isAfter(nextServiceDate!);
  }

  bool get isOperational => status == EquipmentStatus.active;

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'],
      clientId: json['client_id'] ?? json['company_id'] ?? '',
      companyId: json['company_id'],
      companyInn: json['company_inn'],
      supplierId: json['supplier_id'],
      name: json['name'] ?? json['title'] ?? '',
      manufacturer: json['manufacturer'] ?? '',
      model: json['model'] ?? '',
      modification: json['modification'],
      serialNumber: json['serial_number'],
      siteId: json['site_id'],
      location: json['location'] ?? '',
      address: json['address'] ?? '',
      status: EquipmentStatus.values.firstWhere(
        (e) => e.toString() == 'EquipmentStatus.${json['status']}',
        orElse: () => EquipmentStatus.active,
      ),
      responsibleUserId: json['responsible_user_id'],
      description: json['description'],
      imageUrl: json['image_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      installationDate: json['installation_date'] != null
          ? DateTime.parse(json['installation_date'])
          : null,
      lastServiceDate: json['last_service_date'] != null
          ? DateTime.parse(json['last_service_date'])
          : null,
      nextServiceDate: json['next_service_date'] != null
          ? DateTime.parse(json['next_service_date'])
          : null,
      specifications: json['specifications'],
      manuals: json['manuals'] != null 
          ? List<String>.from(json['manuals'])
          : null,
      photos: json['photos'] != null 
          ? List<String>.from(json['photos'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'company_id': companyId,
      'company_inn': companyInn,
      'supplier_id': supplierId,
      'name': name,
      'manufacturer': manufacturer,
      'model': model,
      'modification': modification,
      'serial_number': serialNumber,
      'site_id': siteId,
      'location': location,
      'address': address,
      'status': status.toString().split('.').last,
      'responsible_user_id': responsibleUserId,
      'description': description,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'installation_date': installationDate?.toIso8601String(),
      'last_service_date': lastServiceDate?.toIso8601String(),
      'next_service_date': nextServiceDate?.toIso8601String(),
      'specifications': specifications,
      'manuals': manuals,
      'photos': photos,
    };
  }

  Equipment copyWith({
    String? id,
    String? clientId,
    String? companyId,
    String? companyInn,
    String? supplierId,
    String? name,
    String? manufacturer,
    String? model,
    String? modification,
    String? serialNumber,
    String? siteId,
    String? location,
    String? address,
    EquipmentStatus? status,
    String? responsibleUserId,
    String? description,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? installationDate,
    DateTime? lastServiceDate,
    DateTime? nextServiceDate,
    Map<String, dynamic>? specifications,
    List<String>? manuals,
    List<String>? photos,
  }) {
    return Equipment(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      companyId: companyId ?? this.companyId,
      companyInn: companyInn ?? this.companyInn,
      supplierId: supplierId ?? this.supplierId,
      name: name ?? this.name,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      modification: modification ?? this.modification,
      serialNumber: serialNumber ?? this.serialNumber,
      siteId: siteId ?? this.siteId,
      location: location ?? this.location,
      address: address ?? this.address,
      status: status ?? this.status,
      responsibleUserId: responsibleUserId ?? this.responsibleUserId,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      installationDate: installationDate ?? this.installationDate,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      nextServiceDate: nextServiceDate ?? this.nextServiceDate,
      specifications: specifications ?? this.specifications,
      manuals: manuals ?? this.manuals,
      photos: photos ?? this.photos,
    );
  }
}
