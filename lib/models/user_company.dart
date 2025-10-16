import 'package:uuid/uuid.dart';

/// Связь пользователя с компанией
class UserCompany {
  final String id;
  final String userId;
  final String companyId;
  final String companyInn;
  final String companyName;
  final String role;
  final String status; // pending, approved, rejected
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserCompany({
    required this.id,
    required this.userId,
    required this.companyId,
    required this.companyInn,
    required this.companyName,
    required this.role,
    required this.status,
    required this.requestedAt,
    this.approvedAt,
    this.approvedBy,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserCompany.fromJson(Map<String, dynamic> json) {
    return UserCompany(
      id: json['id'] ?? const Uuid().v4(),
      userId: json['user_id'] ?? '',
      companyId: json['company_id'] ?? '',
      companyInn: json['company_inn'] ?? '',
      companyName: json['company_name'] ?? '',
      role: json['role'] ?? 'companyResponsible',
      status: json['status'] ?? 'pending',
      requestedAt: json['requested_at'] != null 
          ? DateTime.parse(json['requested_at']) 
          : DateTime.now(),
      approvedAt: json['approved_at'] != null 
          ? DateTime.parse(json['approved_at']) 
          : null,
      approvedBy: json['approved_by'],
      rejectionReason: json['rejection_reason'],
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
      'user_id': userId,
      'company_id': companyId,
      'company_inn': companyInn,
      'company_name': companyName,
      'role': role,
      'status': status,
      'requested_at': requestedAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'approved_by': approvedBy,
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserCompany copyWith({
    String? id,
    String? userId,
    String? companyId,
    String? companyInn,
    String? companyName,
    String? role,
    String? status,
    DateTime? requestedAt,
    DateTime? approvedAt,
    String? approvedBy,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserCompany(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      companyInn: companyInn ?? this.companyInn,
      companyName: companyName ?? this.companyName,
      role: role ?? this.role,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Проверяет, является ли пользователь ответственным лицом в этой компании
  bool get isCompanyResponsible => role == 'companyResponsible' && status == 'approved';

  /// Проверяет, одобрена ли связь с компанией
  bool get isApproved => status == 'approved';

  /// Проверяет, ожидает ли заявка подтверждения
  bool get isPending => status == 'pending';

  /// Проверяет, отклонена ли заявка
  bool get isRejected => status == 'rejected';

  /// Получает статус в читаемом виде
  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'Ожидает подтверждения';
      case 'approved':
        return 'Подтверждено';
      case 'rejected':
        return 'Отклонено';
      default:
        return status;
    }
  }

  /// Получает роль в читаемом виде
  String get roleDisplayName {
    switch (role) {
      case 'companyResponsible':
        return 'Ответственное лицо';
      case 'siteManager':
        return 'Менеджер площадки';
      case 'operatorPM':
        return 'Оператор ПМ';
      default:
        return role;
    }
  }
}

/// Заявка на создание новой компании
class CompanyRequest {
  final String id;
  final String userId;
  final String companyName;
  final String companyInn;
  final String? companyAddress;
  final String? companyPhone;
  final String? companyEmail;
  final String requestedRole;
  final String status; // pending, approved, rejected
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyRequest({
    required this.id,
    required this.userId,
    required this.companyName,
    required this.companyInn,
    this.companyAddress,
    this.companyPhone,
    this.companyEmail,
    required this.requestedRole,
    required this.status,
    required this.requestedAt,
    this.approvedAt,
    this.approvedBy,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyRequest.fromJson(Map<String, dynamic> json) {
    return CompanyRequest(
      id: json['id'] ?? const Uuid().v4(),
      userId: json['user_id'] ?? '',
      companyName: json['company_name'] ?? '',
      companyInn: json['company_inn'] ?? '',
      companyAddress: json['company_address'],
      companyPhone: json['company_phone'],
      companyEmail: json['company_email'],
      requestedRole: json['requested_role'] ?? 'companyResponsible',
      status: json['status'] ?? 'pending',
      requestedAt: json['requested_at'] != null 
          ? DateTime.parse(json['requested_at']) 
          : DateTime.now(),
      approvedAt: json['approved_at'] != null 
          ? DateTime.parse(json['approved_at']) 
          : null,
      approvedBy: json['approved_by'],
      rejectionReason: json['rejection_reason'],
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
      'user_id': userId,
      'company_name': companyName,
      'company_inn': companyInn,
      'company_address': companyAddress,
      'company_phone': companyPhone,
      'company_email': companyEmail,
      'requested_role': requestedRole,
      'status': status,
      'requested_at': requestedAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'approved_by': approvedBy,
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CompanyRequest copyWith({
    String? id,
    String? userId,
    String? companyName,
    String? companyInn,
    String? companyAddress,
    String? companyPhone,
    String? companyEmail,
    String? requestedRole,
    String? status,
    DateTime? requestedAt,
    DateTime? approvedAt,
    String? approvedBy,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyName: companyName ?? this.companyName,
      companyInn: companyInn ?? this.companyInn,
      companyAddress: companyAddress ?? this.companyAddress,
      companyPhone: companyPhone ?? this.companyPhone,
      companyEmail: companyEmail ?? this.companyEmail,
      requestedRole: requestedRole ?? this.requestedRole,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Проверяет, одобрена ли заявка
  bool get isApproved => status == 'approved';

  /// Проверяет, ожидает ли заявка подтверждения
  bool get isPending => status == 'pending';

  /// Проверяет, отклонена ли заявка
  bool get isRejected => status == 'rejected';

  /// Получает статус в читаемом виде
  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'Ожидает подтверждения';
      case 'approved':
        return 'Подтверждено';
      case 'rejected':
        return 'Отклонено';
      default:
        return status;
    }
  }

  /// Получает роль в читаемом виде
  String get roleDisplayName {
    switch (requestedRole) {
      case 'companyResponsible':
        return 'Ответственное лицо';
      case 'siteManager':
        return 'Менеджер площадки';
      case 'operatorPM':
        return 'Оператор ПМ';
      default:
        return requestedRole;
    }
  }
}
