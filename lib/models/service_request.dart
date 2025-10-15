enum RequestType {
  repair,           // Ремонт
  specialistVisit,  // Вызов специалиста
  partsOrder,       // Заказ запчастей
  maintenance,      // Техническое обслуживание
}

enum RequestStatus {
  draft,           // Черновик
  pending,         // Ожидает согласования
  approved,        // Одобрена
  rejected,        // Отклонена
  inProgress,      // В работе
  completed,       // Выполнена
  cancelled,       // Отменена
}

enum RequestPriority {
  low,             // Низкий
  normal,          // Обычный
  high,            // Высокий
  urgent,          // Срочный
}

class ServiceRequest {
  final String id;
  final String clientId;               // Для обратной совместимости
  final String? companyId;             // Новое поле для Supabase
  final String userId;                    // Кто создал заявку
  final RequestType type;
  final String title;
  final String description;
  final RequestStatus status;
  final RequestPriority priority;
  final String? equipmentId;
  final Map<String, dynamic>? partsOrderDetails;
  
  // Поля для согласования
  final String? approvedByUserId;         // Кто одобрил
  final DateTime? approvedAt;             // Когда одобрили
  final String? rejectionReason;          // Причина отклонения
  
  // Временные метки
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? scheduledAt;            // Запланированная дата выполнения
  
  // Дополнительные поля
  final List<String>? attachments;        // Вложения (фото, документы)
  final double? estimatedCost;            // Предварительная стоимость
  final Map<String, dynamic>? metadata;   // Дополнительные данные
  
  // Поля для работы инженеров
  final String? assignedEngineerId;       // ID назначенного инженера
  final String? engineerComment;          // Комментарий инженера
  final DateTime? engineerStartedAt;     // Время начала работы инженера
  final DateTime? engineerCompletedAt;   // Время завершения работы инженера

  ServiceRequest({
    required this.id,
    required this.clientId,
    this.companyId,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    required this.status,
    this.priority = RequestPriority.normal,
    this.equipmentId,
    this.partsOrderDetails,
    this.approvedByUserId,
    this.approvedAt,
    this.rejectionReason,
    required this.createdAt,
    this.completedAt,
    this.scheduledAt,
    this.attachments,
    this.estimatedCost,
    this.metadata,
    this.assignedEngineerId,
    this.engineerComment,
    this.engineerStartedAt,
    this.engineerCompletedAt,
  });

  // Геттеры для удобства
  String get statusDisplayName {
    switch (status) {
      case RequestStatus.draft:
        return 'Черновик';
      case RequestStatus.pending:
        return 'На согласовании';
      case RequestStatus.approved:
        return 'Одобрена';
      case RequestStatus.rejected:
        return 'Отклонена';
      case RequestStatus.inProgress:
        return 'В работе';
      case RequestStatus.completed:
        return 'Выполнена';
      case RequestStatus.cancelled:
        return 'Отменена';
    }
  }

  String get typeDisplayName {
    switch (type) {
      case RequestType.repair:
        return 'Ремонт';
      case RequestType.specialistVisit:
        return 'Вызов специалиста';
      case RequestType.partsOrder:
        return 'Заказ запчастей';
      case RequestType.maintenance:
        return 'ТО';
    }
  }

  String get priorityDisplayName {
    switch (priority) {
      case RequestPriority.low:
        return 'Низкий';
      case RequestPriority.normal:
        return 'Обычный';
      case RequestPriority.high:
        return 'Высокий';
      case RequestPriority.urgent:
        return 'Срочный';
    }
  }

  bool get canBeApproved => status == RequestStatus.pending;
  bool get canBeRejected => status == RequestStatus.pending;
  bool get canBeEdited => status == RequestStatus.draft || status == RequestStatus.rejected;
  bool get isCompleted => status == RequestStatus.completed;
  
  // Геттеры для работы инженеров
  bool get isAssignedToEngineer => assignedEngineerId != null;
  bool get canEngineerStart => status == RequestStatus.approved && assignedEngineerId != null && engineerStartedAt == null;
  bool get canEngineerComplete => status == RequestStatus.inProgress && assignedEngineerId != null && engineerStartedAt != null;
  bool get isEngineerWorking => status == RequestStatus.inProgress && engineerStartedAt != null;
  
  // Время выполнения заявки инженером
  Duration? get engineerWorkDuration {
    if (engineerStartedAt == null) return null;
    final endTime = engineerCompletedAt ?? DateTime.now();
    return endTime.difference(engineerStartedAt!);
  }

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'],
      clientId: json['client_id'] ?? json['company_id'] ?? '',
      companyId: json['company_id'],
      userId: json['user_id'],
      type: RequestType.values.firstWhere(
        (e) => e.toString() == 'RequestType.${json['type']}',
        orElse: () => RequestType.repair,
      ),
      title: json['title'],
      description: json['description'],
      status: RequestStatus.values.firstWhere(
        (e) => e.toString() == 'RequestStatus.${json['status']}',
        orElse: () => RequestStatus.pending,
      ),
      priority: RequestPriority.values.firstWhere(
        (e) => e.toString() == 'RequestPriority.${json['priority']}',
        orElse: () => RequestPriority.normal,
      ),
      equipmentId: json['equipment_id'],
      partsOrderDetails: json['parts_order_details'],
      approvedByUserId: json['approved_by_user_id'],
      approvedAt: json['approved_at'] != null 
          ? DateTime.parse(json['approved_at']) 
          : null,
      rejectionReason: json['rejection_reason'],
      createdAt: DateTime.parse(json['created_at']),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
      scheduledAt: json['scheduled_at'] != null 
          ? DateTime.parse(json['scheduled_at']) 
          : null,
      attachments: json['attachments'] != null 
          ? List<String>.from(json['attachments'])
          : null,
      estimatedCost: json['estimated_cost']?.toDouble(),
      metadata: json['metadata'],
      assignedEngineerId: json['assigned_engineer_id'],
      engineerComment: json['engineer_comment'],
      engineerStartedAt: json['engineer_started_at'] != null 
          ? DateTime.parse(json['engineer_started_at']) 
          : null,
      engineerCompletedAt: json['engineer_completed_at'] != null 
          ? DateTime.parse(json['engineer_completed_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'company_id': companyId,
      'user_id': userId,
      'type': type.toString().split('.').last,
      'title': title,
      'description': description,
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'equipment_id': equipmentId,
      'parts_order_details': partsOrderDetails,
      'approved_by_user_id': approvedByUserId,
      'approved_at': approvedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'scheduled_at': scheduledAt?.toIso8601String(),
      'attachments': attachments,
      'estimated_cost': estimatedCost,
      'metadata': metadata,
      'assigned_engineer_id': assignedEngineerId,
      'engineer_comment': engineerComment,
      'engineer_started_at': engineerStartedAt?.toIso8601String(),
      'engineer_completed_at': engineerCompletedAt?.toIso8601String(),
    };
  }

  ServiceRequest copyWith({
    String? id,
    String? clientId,
    String? userId,
    RequestType? type,
    String? title,
    String? description,
    RequestStatus? status,
    RequestPriority? priority,
    String? equipmentId,
    Map<String, dynamic>? partsOrderDetails,
    String? approvedByUserId,
    DateTime? approvedAt,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? scheduledAt,
    List<String>? attachments,
    double? estimatedCost,
    Map<String, dynamic>? metadata,
    String? assignedEngineerId,
    String? engineerComment,
    DateTime? engineerStartedAt,
    DateTime? engineerCompletedAt,
  }) {
    return ServiceRequest(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      equipmentId: equipmentId ?? this.equipmentId,
      partsOrderDetails: partsOrderDetails ?? this.partsOrderDetails,
      approvedByUserId: approvedByUserId ?? this.approvedByUserId,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      attachments: attachments ?? this.attachments,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      metadata: metadata ?? this.metadata,
      assignedEngineerId: assignedEngineerId ?? this.assignedEngineerId,
      engineerComment: engineerComment ?? this.engineerComment,
      engineerStartedAt: engineerStartedAt ?? this.engineerStartedAt,
      engineerCompletedAt: engineerCompletedAt ?? this.engineerCompletedAt,
    );
  }
}
