class EquipmentModel {
  final String id;
  final String? supplierId;
  final String manufacturer;
  final String model;
  final String? imageUrl;
  final Map<String, dynamic> specifications;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EquipmentModel({
    required this.id,
    this.supplierId,
    required this.manufacturer,
    required this.model,
    this.imageUrl,
    this.specifications = const {},
    required this.createdAt,
    this.updatedAt,
  });

  String get fullTitle => '$manufacturer $model';

  factory EquipmentModel.fromJson(Map<String, dynamic> json) {
    return EquipmentModel(
      id: json['id'],
      supplierId: json['supplier_id'],
      manufacturer: json['manufacturer'] ?? '',
      model: json['model'] ?? '',
      imageUrl: json['image_url'],
      specifications: json['specifications'] ?? {},
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'manufacturer': manufacturer,
      'model': model,
      'image_url': imageUrl,
      'specifications': specifications,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  EquipmentModel copyWith({
    String? id,
    String? supplierId,
    String? manufacturer,
    String? model,
    String? imageUrl,
    Map<String, dynamic>? specifications,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EquipmentModel(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      imageUrl: imageUrl ?? this.imageUrl,
      specifications: specifications ?? this.specifications,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
