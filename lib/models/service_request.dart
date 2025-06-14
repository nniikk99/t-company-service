class ServiceRequest {
  final String id;
  final String title;
  final String description;
  final String status;
  final String equipmentId;
  final String userId;
  final DateTime createdAt;
  final DateTime? completedAt;

  ServiceRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.equipmentId,
    required this.userId,
    required this.createdAt,
    this.completedAt,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      equipmentId: json['equipment_id'] as String,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'equipment_id': equipmentId,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
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