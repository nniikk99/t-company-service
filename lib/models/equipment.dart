class Equipment {
  final String id;
  final String manufacturer;
  final String model;
  final String serialNumber;
  final String address;
  final String contactPerson;
  final String phone;
  final String status;
  final String ownership;
  final DateTime lastMaintenance;
  final DateTime nextMaintenance;

  Equipment({
    required this.id,
    required this.manufacturer,
    required this.model,
    required this.serialNumber,
    required this.address,
    required this.contactPerson,
    required this.phone,
    required this.status,
    required this.ownership,
    required this.lastMaintenance,
    required this.nextMaintenance,
  });

  Equipment copyWith({
    String? manufacturer,
    String? model,
    String? serialNumber,
    String? address,
    String? contactPerson,
    String? phone,
    String? status,
    String? ownership,
    DateTime? lastMaintenance,
    DateTime? nextMaintenance,
  }) {
    return Equipment(
      id: id,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      ownership: ownership ?? this.ownership,
      lastMaintenance: lastMaintenance ?? this.lastMaintenance,
      nextMaintenance: nextMaintenance ?? this.nextMaintenance,
    );
  }

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] ?? '',
      manufacturer: json['manufacturer'] ?? '',
      model: json['model'] ?? '',
      serialNumber: json['serialNumber'] ?? '',
      address: json['address'] ?? '',
      contactPerson: json['contactPerson'] ?? '',
      phone: json['phone'] ?? '',
      status: json['status'] ?? '',
      ownership: json['ownership'] ?? '',
      lastMaintenance: json['lastMaintenance'] != null
          ? DateTime.parse(json['lastMaintenance'])
          : DateTime.now(),
      nextMaintenance: json['nextMaintenance'] != null
          ? DateTime.parse(json['nextMaintenance'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'manufacturer': manufacturer,
      'model': model,
      'serialNumber': serialNumber,
      'address': address,
      'contactPerson': contactPerson,
      'phone': phone,
      'status': status,
      'ownership': ownership,
      'lastMaintenance': lastMaintenance.toIso8601String(),
      'nextMaintenance': nextMaintenance.toIso8601String(),
    };
  }
}