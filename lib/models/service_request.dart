enum ServiceRequestStatus {
  newRequest,
  assigned,
  completed,
}

class ServiceRequest {
  final String id;
  final String title;
  final String description;
  final String equipmentId;
  final String userId;
  final DateTime createdAt;
  final ServiceRequestStatus status;
  final String? engineerId;
  final DateTime? visitDate;
  final bool isArchived;
  final String? invoiceUrl;
  final double? invoiceAmount;
  final bool isPaid;

  ServiceRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.equipmentId,
    required this.userId,
    required this.createdAt,
    this.status = ServiceRequestStatus.newRequest,
    this.engineerId,
    this.visitDate,
    this.isArchived = false,
    this.invoiceUrl,
    this.invoiceAmount,
    this.isPaid = false,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      equipmentId: json['equipment_id'] as String,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: ServiceRequestStatus.values.firstWhere(
        (e) => e.toString() == 'ServiceRequestStatus.${json['status']}',
        orElse: () => ServiceRequestStatus.newRequest,
      ),
      engineerId: json['engineer_id'] as String?,
      visitDate: json['visit_date'] != null ? DateTime.parse(json['visit_date']) : null,
      isArchived: json['is_archived'] ?? false,
      invoiceUrl: json['invoice_url'] as String?,
      invoiceAmount: json['invoice_amount'] != null ? double.tryParse(json['invoice_amount'].toString()) : null,
      isPaid: json['is_paid'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'equipment_id': equipmentId,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'status': status.toString().split('.').last,
      'engineer_id': engineerId,
      'visit_date': visitDate?.toIso8601String(),
      'is_archived': isArchived,
      'invoice_url': invoiceUrl,
      'invoice_amount': invoiceAmount,
      'is_paid': isPaid,
    };
  }
}

class Comment {
  final String authorId;
  final String authorRole;
  final String text;
  final DateTime timestamp;

  Comment({
    required this.authorId,
    required this.authorRole,
    required this.text,
    required this.timestamp,
  });
} 