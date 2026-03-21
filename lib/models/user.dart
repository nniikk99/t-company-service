enum UserRole {
  // Новые упрощенные роли (по возрастанию)
  pendingApproval,    // Ожидает подтверждения
  operatorPM,         // Оператор ПМ
  engineer,           // Инженер (работает только с заявками)
  siteManager,        // Менеджер площадки  
  companyResponsible,  // Ответственное лицо
  supplier,           // Поставщик (новая роль для маркетплейса)
  administrator,      // Администратор
  
  // Старые роли (для совместимости)
  clientManager,
  clientResponsible,
  contactPerson,
}

class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final UserRole role;
  
  // Новые поля для расширенной регистрации
  final String position;                    // Должность пользователя
  final String? companyId;                  // ID компании
  final String? companyName;                // Название компании (для отображения)
  final String? companyInn;                 // ИНН компании (для поиска при регистрации)
  final String? companyAddress;             // Адрес компании
  final String? companyPhone;              // Телефон компании
  final String? companyEmail;              // Email компании
  // Совместимость со старыми экранами
  final List<String>? equipmentIds;
  
  // Управление правами и доступом
  final bool canManageRequestsIndependently; // Может управлять заявками без согласования
  final List<String>? assignedSiteIds;       // Назначенные площадки (для siteManager)
  final String? supplierId;                  // ID поставщика (для роли supplier)
  final String? createdBy;                   // Кто создал/одобрил пользователя
  final String? passwordHash;               // Хэш пароля для безопасности
  final List<String>? serviceRegions;       // Регионы обслуживания для инженера
  
  // Telegram интеграция
  final String? telegramId;
  final int? telegramUserId;
  final String? telegramUsername;
  
  // Системные поля
  final bool consentToPersonalData;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    required this.position,
    this.companyId,
    this.companyName,
    this.companyInn,
    this.companyAddress,
    this.companyPhone,
    this.companyEmail,
    this.equipmentIds,
    this.canManageRequestsIndependently = false,
    this.assignedSiteIds,
    this.supplierId,
    this.createdBy,
    this.passwordHash,
    this.serviceRegions,
    this.telegramId,
    this.telegramUserId,
    this.telegramUsername,
    required this.consentToPersonalData,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  // Геттеры для удобства
  String get fullName => '$firstName $lastName';
  
  String get roleDisplayName {
    switch (role) {
      case UserRole.administrator:
        return 'Администратор';
      case UserRole.clientManager:
        return 'Менеджер клиента';
      case UserRole.clientResponsible:
        return 'Ответственное лицо';
      case UserRole.contactPerson:
        return 'Контактное лицо';
      case UserRole.administrator:
        return 'Администратор';
      case UserRole.companyResponsible:
        return 'Ответственное лицо компании';
      case UserRole.supplier:
        return 'Поставщик';
      case UserRole.siteManager:
        return 'Менеджер площадки';
      case UserRole.operatorPM:
        return 'Оператор ПМ';
      case UserRole.engineer:
        return 'Инженер';
      case UserRole.pendingApproval:
        return 'Ожидает одобрения';
    }
  }

  // Новые права доступа под новую систему + обратная совместимость
  bool get canCreateRequests => role == UserRole.siteManager || role == UserRole.companyResponsible || role == UserRole.contactPerson || role == UserRole.clientResponsible || role == UserRole.operatorPM;
  bool get canApproveRequests => role == UserRole.companyResponsible || role == UserRole.administrator || role == UserRole.clientResponsible;
  bool get canManageClients => role == UserRole.administrator;
  bool get canViewAllCompanies => role == UserRole.administrator;
  bool get canManageCompany => role == UserRole.companyResponsible || role == UserRole.administrator || role == UserRole.clientResponsible;
  bool get canAssignSiteManagers => role == UserRole.companyResponsible || role == UserRole.clientResponsible || role == UserRole.administrator;
  bool get canManageRequestsWithoutApproval => canManageRequestsIndependently && role == UserRole.siteManager;
  bool get needsApproval => role == UserRole.pendingApproval;
  
  // Права на управление площадками и оборудованием
  bool get canManageSites => role == UserRole.companyResponsible || role == UserRole.administrator;
  bool get canManageEquipment => role == UserRole.supplier || role == UserRole.companyResponsible || role == UserRole.siteManager || role == UserRole.operatorPM || role == UserRole.administrator;
  
  // Права для инженеров
  bool get canWorkWithRequests => role == UserRole.engineer;
  bool get canViewAssignedRequests => role == UserRole.engineer;
  
  // Права для поставщиков
  bool get canAssignEngineers => role == UserRole.supplier;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      phone: json['phone'] ?? json['contact_phone'] ?? '',
      role: _parseRole(json['role']),
      position: json['position'] ?? '',
      companyId: json['company_id'],
      companyName: json['company_name'] ?? json['companies']?['name'], // Из joined таблицы
      companyInn: json['company_inn'],
      companyAddress: json['company_address'],
      companyPhone: json['company_phone'],
      companyEmail: json['company_email'],
      equipmentIds: json['equipment_ids'] != null ? List<String>.from(json['equipment_ids']) : null,
      canManageRequestsIndependently: json['can_manage_requests_independently'] ?? false,
      assignedSiteIds: json['assigned_site_ids'] != null 
          ? List<String>.from(json['assigned_site_ids'])
          : null,
      supplierId: json['supplier_id'],
      createdBy: json['created_by'],
      passwordHash: json['password_hash'],
      serviceRegions: json['service_regions'] != null 
          ? List<String>.from(json['service_regions'])
          : null,
      telegramId: json['telegram_id']?.toString(),
      telegramUserId: json['telegram_user_id'],
      telegramUsername: json['telegram_username'],
      consentToPersonalData: json['consent_to_personal_data'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  static UserRole _parseRole(String? role) {
    switch (role) {
      // Новые роли (camelCase - как в базе данных)
      case 'pendingApproval':
        return UserRole.pendingApproval;
      case 'operatorPM':
        return UserRole.operatorPM;
      case 'engineer':
        return UserRole.engineer;
      case 'siteManager':
        return UserRole.siteManager;
      case 'companyResponsible':
        return UserRole.companyResponsible;
      case 'supplier':
        return UserRole.supplier;
      case 'administrator':
      case 'superAdmin':
        return UserRole.administrator;
      
      // Старые роли (snake_case - для совместимости)
      case 'pending_approval':
        return UserRole.pendingApproval;
      case 'operator_pm':
        return UserRole.operatorPM;
      case 'site_manager':
        return UserRole.siteManager;
      case 'company_responsible':
        return UserRole.companyResponsible;
      case 'super_admin':
        return UserRole.administrator;
      
      // Еще более старые роли (для совместимости)
      case 'admin':
        return UserRole.administrator;
      case 'client_manager':
        return UserRole.clientManager;
      case 'responsible_person':
        return UserRole.clientResponsible;
      case 'contact_person':
        return UserRole.contactPerson;
      default:
        print('⚠️ Неизвестная роль: $role, устанавливаем pendingApproval');
        return UserRole.pendingApproval;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'role': _roleToString(role),
      'position': position,
      'company_id': companyId,
      'company_name': companyName,
      'company_inn': companyInn,
      'inn': companyInn,
      'company_address': companyAddress,
      'company_phone': companyPhone,
      'company_email': companyEmail,
      'equipment_ids': equipmentIds,
      'can_manage_requests_independently': canManageRequestsIndependently,
      'assigned_site_ids': assignedSiteIds,
      'supplier_id': supplierId,
      'created_by': createdBy,
      'password_hash': passwordHash,
      'service_regions': serviceRegions,
      'telegram_id': telegramId,
      'telegram_user_id': telegramUserId,
      'telegram_username': telegramUsername,
      'consent_to_personal_data': consentToPersonalData,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static String _roleToString(UserRole role) {
    switch (role) {
      // Новые роли (camelCase - основной формат)
      case UserRole.pendingApproval:
        return 'pendingApproval';
      case UserRole.operatorPM:
        return 'operatorPM';
      case UserRole.siteManager:
        return 'siteManager';
      case UserRole.companyResponsible:
        return 'companyResponsible';
      case UserRole.supplier:
        return 'supplier';
      case UserRole.administrator:
        return 'administrator';
      case UserRole.engineer:
        return 'engineer';
      
      // Старые роли (для совместимости)
      case UserRole.clientManager:
        return 'clientManager';
      case UserRole.clientResponsible:
        return 'companyResponsible';
      case UserRole.contactPerson:
        return 'siteManager';
    }
  }

  User copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    UserRole? role,
    String? position,
    String? companyId,
    String? companyName,
    String? companyInn,
    String? companyAddress,
    String? companyPhone,
    String? companyEmail,
    List<String>? equipmentIds,
    bool? canManageRequestsIndependently,
    List<String>? assignedSiteIds,
    String? createdBy,
    String? passwordHash,
    String? telegramId,
    int? telegramUserId,
    String? telegramUsername,
    bool? consentToPersonalData,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      position: position ?? this.position,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyInn: companyInn ?? this.companyInn,
      companyAddress: companyAddress ?? this.companyAddress,
      companyPhone: companyPhone ?? this.companyPhone,
      companyEmail: companyEmail ?? this.companyEmail,
      equipmentIds: equipmentIds ?? this.equipmentIds,
      canManageRequestsIndependently: canManageRequestsIndependently ?? this.canManageRequestsIndependently,
      assignedSiteIds: assignedSiteIds ?? this.assignedSiteIds,
      createdBy: createdBy ?? this.createdBy,
      passwordHash: passwordHash ?? this.passwordHash,
      telegramId: telegramId ?? this.telegramId,
      telegramUserId: telegramUserId ?? this.telegramUserId,
      telegramUsername: telegramUsername ?? this.telegramUsername,
      consentToPersonalData: consentToPersonalData ?? this.consentToPersonalData,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}