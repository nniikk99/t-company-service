class ServiceRequest {
  final String id;
  final String equipmentTitle;
  final String type; // 'Запчасти' или 'Инженер'
  final String message;
  final DateTime date;
  String status; // 'Отправлено', 'В обработке', 'Завершено'
  final String? engineerId; // id инженера, если назначен
  final List<Comment> comments; // чат по заявке

  ServiceRequest({
    required this.id,
    required this.equipmentTitle,
    required this.type,
    required this.message,
    required this.date,
    this.status = 'Отправлено',
    this.engineerId,
    this.comments = const [],
  });
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