class ServiceRequest {
  final String id;
  final String equipmentTitle;
  final String type; // 'Запчасти' или 'Инженер'
  final String message;
  final DateTime date;
  String status; // 'Отправлено', 'В обработке', 'Завершено'

  ServiceRequest({
    required this.id,
    required this.equipmentTitle,
    required this.type,
    required this.message,
    required this.date,
    this.status = 'Отправлено',
  });
} 