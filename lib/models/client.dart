class Client {
  final String id;
  final String name;
  final String address;
  final String contactPhone;
  final String contactEmail;
  final List<String> managerIds;
  final List<String> responsibleIds;
  final DateTime createdAt;

  Client({
    required this.id,
    required this.name,
    required this.address,
    required this.contactPhone,
    required this.contactEmail,
    required this.managerIds,
    required this.responsibleIds,
    required this.createdAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      contactPhone: json['contact_phone'],
      contactEmail: json['contact_email'],
      managerIds: List<String>.from(json['manager_ids'] ?? []),
      responsibleIds: List<String>.from(json['responsible_ids'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'manager_ids': managerIds,
      'responsible_ids': responsibleIds,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
