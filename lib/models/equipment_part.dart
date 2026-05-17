class EquipmentPart {
  final String id;
  final String equipmentModel;
  final String manufacturer;
  final int positionNumber;
  final String article;
  final String name;
  final String? description;
  final String? supplierId;
  final DateTime createdAt;

  EquipmentPart({
    required this.id,
    required this.equipmentModel,
    required this.manufacturer,
    required this.positionNumber,
    required this.article,
    required this.name,
    this.description,
    this.supplierId,
    required this.createdAt,
  });

  factory EquipmentPart.fromJson(Map<String, dynamic> json) {
    return EquipmentPart(
      id: json['id'],
      equipmentModel: json['equipment_model'],
      manufacturer: json['manufacturer'],
      positionNumber: json['position_number'],
      article: json['article'],
      name: json['name'],
      description: json['description'],
      supplierId: json['supplier_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'equipment_model': equipmentModel,
    'manufacturer': manufacturer,
    'position_number': positionNumber,
    'article': article,
    'name': name,
    'description': description,
    'supplier_id': supplierId,
    'created_at': createdAt.toIso8601String(),
  };
}

class RecommendedPart {
  final int position;
  final String article;
  final String name;
  final int qty;

  RecommendedPart({
    required this.position,
    required this.article,
    required this.name,
    required this.qty,
  });

  factory RecommendedPart.fromJson(Map<String, dynamic> json) {
    return RecommendedPart(
      position: json['position'] as int,
      article: json['article'] as String,
      name: json['name'] as String,
      qty: json['qty'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'position': position,
    'article': article,
    'name': name,
    'qty': qty,
  };

  RecommendedPart copyWith({int? qty}) => RecommendedPart(
    position: position,
    article: article,
    name: name,
    qty: qty ?? this.qty,
  );
}
