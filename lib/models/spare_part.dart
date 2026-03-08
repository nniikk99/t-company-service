import 'package:uuid/uuid.dart';

class SparePart {
  final String id;
  final String supplierId;
  final String article;
  final String name;
  final String? description;
  final double price;
  final String category;
  final List<String> images;
  final List<String> compatibleModels;
  final bool inStock;
  final DateTime createdAt;
  final DateTime updatedAt;

  SparePart({
    String? id,
    required this.supplierId,
    required this.article,
    required this.name,
    this.description,
    required this.price,
    required this.category,
    this.images = const [],
    this.compatibleModels = const [],
    this.inStock = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory SparePart.fromJson(Map<String, dynamic> json) {
    return SparePart(
      id: json['id'],
      supplierId: json['supplier_id'],
      article: json['article'],
      name: json['name'],
      description: json['description'],
      price: (json['price'] ?? 0).toDouble(),
      category: json['category'],
      images: List<String>.from(json['images'] ?? []),
      compatibleModels: List<String>.from(json['compatible_models'] ?? []),
      inStock: json['in_stock'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'supplier_id': supplierId,
      'article': article,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'images': images,
      'compatible_models': compatibleModels,
      'in_stock': inStock,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SparePart copyWith({
    String? id,
    String? supplierId,
    String? article,
    String? name,
    String? description,
    double? price,
    String? category,
    List<String>? images,
    List<String>? compatibleModels,
    bool? inStock,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SparePart(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      article: article ?? this.article,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      images: images ?? this.images,
      compatibleModels: compatibleModels ?? this.compatibleModels,
      inStock: inStock ?? this.inStock,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
