import 'package:intl/intl.dart';

class RequestMessage {
  final String id;
  final String requestId;
  final String senderId;
  final String? senderName;
  final String? message;
  final List<String>? attachments;
  final DateTime createdAt;

  RequestMessage({
    required this.id,
    required this.requestId,
    required this.senderId,
    this.senderName,
    this.message,
    this.attachments,
    required this.createdAt,
  });

  factory RequestMessage.fromJson(Map<String, dynamic> json) {
    final senderProfile = json['sender'] as Map<String, dynamic>?;
    final senderName = senderProfile != null 
        ? '${senderProfile['first_name']} ${senderProfile['last_name']}'
        : null;

    return RequestMessage(
      id: json['id'],
      requestId: json['request_id'],
      senderId: json['sender_id'],
      senderName: senderName,
      message: json['message'],
      attachments: json['attachments'] != null ? List<String>.from(json['attachments']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'sender_id': senderId,
      'message': message,
      'attachments': attachments,
    };
  }

  String get formattedTime {
    return DateFormat('HH:mm').format(createdAt.toLocal());
  }

  String get formattedDate {
    return DateFormat('dd.MM.yyyy').format(createdAt.toLocal());
  }
}
