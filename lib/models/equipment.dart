enum EquipmentStatus {
  active,
  maintenance,
  inactive,
}

class Equipment {
  final String id;
  final String clientId;
  final String title;
  final String model;
  final String location;
  final String address;
  final EquipmentStatus status;
  final DateTime createdAt;

  Equipment({
    required this.id,
    required this.clientId,
    required this.title,
    required this.model,
    required this.location,
    required this.address,
    required this.status,
    required this.createdAt,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'],
      clientId: json['client_id'],
      title: json['title'],
      model: json['model'],
      location: json['location'],
      address: json['address'],
      status: EquipmentStatus.values.firstWhere(
        (e) => e.toString() == 'EquipmentStatus.${json['status']}',
        orElse: () => EquipmentStatus.active,
      ),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'title': title,
      'model': model,
      'location': location,
      'address': address,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
