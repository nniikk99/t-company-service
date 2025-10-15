enum NotificationType {
  newRequest,
  requestApproved, 
  requestRejected,
  requestCompleted,
  invoiceReady,
  systemAlert,
  companyJoinRequest,
  companyCreationRequest,
  siteAssignment,
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      type: _parseNotificationType(json['type']),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['is_read'] ?? json['isRead'] ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static NotificationType _parseNotificationType(String? type) {
    if (type == null) return NotificationType.systemAlert;
    
    switch (type) {
      case 'newRequest':
        return NotificationType.newRequest;
      case 'requestApproved':
        return NotificationType.requestApproved;
      case 'requestRejected':
        return NotificationType.requestRejected;
      case 'requestCompleted':
        return NotificationType.requestCompleted;
      case 'invoiceReady':
        return NotificationType.invoiceReady;
      case 'systemAlert':
        return NotificationType.systemAlert;
      case 'companyJoinRequest':
        return NotificationType.companyJoinRequest;
      case 'companyCreationRequest':
        return NotificationType.companyCreationRequest;
      case 'siteAssignment':
        return NotificationType.siteAssignment;
      default:
        return NotificationType.systemAlert;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.toString().split('.').last,
      'title': title,
      'message': message,
      'data': data,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}