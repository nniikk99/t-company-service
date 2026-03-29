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
  final String? kpp;
  final String? ogrn;
  final String? orgForm;        // 'ИП', 'ООО', 'АО'
  final String? legalAddress;
  final String? city;
  final String? directorName;
  final String? directorBasis;  // 'Устав', 'Доверенность'
  final String? registrationNumber;
  
  // Банковские реквизиты
  final String? bankName;
  final String? bik;
  final String? checkingAccount;
  final String? correspondentAccount;
  
  // Документы и НДС
  final bool vatIncluded;
  final String? signatureUrl;
  final String? stampUrl;

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
    this.kpp,
    this.ogrn,
    this.orgForm,
    this.legalAddress,
    this.city,
    this.directorName,
    this.directorBasis,
    this.registrationNumber,
    this.bankName,
    this.bik,
    this.checkingAccount,
    this.correspondentAccount,
    this.vatIncluded = false,
    this.signatureUrl,
    this.stampUrl,
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
      kpp: json['kpp'],
      ogrn: json['ogrn'],
      orgForm: json['org_form'],
      legalAddress: json['legal_address'],
      city: json['city'],
      directorName: json['director_name'],
      directorBasis: json['director_basis'],
      registrationNumber: json['registration_number'],
      bankName: json['bank_name'],
      bik: json['bik'],
      checkingAccount: json['checking_account'],
      correspondentAccount: json['correspondent_account'],
      vatIncluded: json['vat_included'] ?? false,
      signatureUrl: json['signature_url'],
      stampUrl: json['stamp_url'],
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
      if (kpp != null) 'kpp': kpp,
      if (ogrn != null) 'ogrn': ogrn,
      if (orgForm != null) 'org_form': orgForm,
      if (legalAddress != null) 'legal_address': legalAddress,
      if (city != null) 'city': city,
      if (directorName != null) 'director_name': directorName,
      if (directorBasis != null) 'director_basis': directorBasis,
      if (registrationNumber != null) 'registration_number': registrationNumber,
      if (bankName != null) 'bank_name': bankName,
      if (bik != null) 'bik': bik,
      if (checkingAccount != null) 'checking_account': checkingAccount,
      if (correspondentAccount != null) 'correspondent_account': correspondentAccount,
      'vat_included': vatIncluded,
      if (signatureUrl != null) 'signature_url': signatureUrl,
      if (stampUrl != null) 'stamp_url': stampUrl,
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
    String? kpp,
    String? ogrn,
    String? orgForm,
    String? legalAddress,
    String? city,
    String? directorName,
    String? directorBasis,
    String? registrationNumber,
    String? bankName,
    String? bik,
    String? checkingAccount,
    String? correspondentAccount,
    bool? vatIncluded,
    String? signatureUrl,
    String? stampUrl,
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
      kpp: kpp ?? this.kpp,
      ogrn: ogrn ?? this.ogrn,
      orgForm: orgForm ?? this.orgForm,
      legalAddress: legalAddress ?? this.legalAddress,
      city: city ?? this.city,
      directorName: directorName ?? this.directorName,
      directorBasis: directorBasis ?? this.directorBasis,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      bankName: bankName ?? this.bankName,
      bik: bik ?? this.bik,
      checkingAccount: checkingAccount ?? this.checkingAccount,
      correspondentAccount: correspondentAccount ?? this.correspondentAccount,
      vatIncluded: vatIncluded ?? this.vatIncluded,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      stampUrl: stampUrl ?? this.stampUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Проверяет, заполнены ли минимально необходимые реквизиты для документов
  bool get isRequisitesComplete {
    return name.isNotEmpty &&
           inn != null && inn!.isNotEmpty &&
           bankName != null && bankName!.isNotEmpty &&
           bik != null && bik!.isNotEmpty &&
           checkingAccount != null && checkingAccount!.isNotEmpty;
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

