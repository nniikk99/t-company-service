enum RequestType {
  repair,
  specialistVisit,
}

enum RequestStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

class ServiceRequest {
  final String id;
  final String clientId;
  final String userId;
  final RequestType type;
  final String title;
  final String description;
  final RequestStatus status;
  final String? equipmentId;
  final Map<String, dynamic>? partsOrderDetails;
  final DateTime createdAt;
  final DateTime? completedAt;

  ServiceRequest({
    required this.id,
    required this.clientId,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    required this.status,
    this.equipmentId,
    this.partsOrderDetails,
    required this.createdAt,
    this.completedAt,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'],
      clientId: json['client_id'],
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
      equipmentId: json['equipment_id'],
      partsOrderDetails: json['parts_order_details'],
      createdAt: DateTime.parse(json['created_at']),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'user_id': userId,
      'type': type.toString().split('.').last,
      'title': title,
      'description': description,
      'status': status.toString().split('.').last,
      'equipment_id': equipmentId,
      'parts_order_details': partsOrderDetails,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}
